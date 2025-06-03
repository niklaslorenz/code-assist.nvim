local Util = require("code-assist.util")
local Message = require("code-assist.chat-completion.message")
local SystemMessage = require("code-assist.chat-completion.system-message")
local Conversation = require("code-assist.conversations.conversation")
local Item = require("code-assist.conversations.item")
local Interface = require("code-assist.api.chat-completion")
local Debouncer = require("code-assist.debouncer")
local IO = require("code-assist.conversations.io")

--- @alias ChatCompletionReasoningEffort "low"|"medium"|"high"

--- @class ChatCompletion

--- @class ChatCompletionConversation: Conversation
--- Class Methods
--- @field new fun(conv: ChatCompletionConversation, name: string?, path: string?, agent: string?): ChatCompletionConversation
--- @field create_unlisted fun(conv: ChatCompletionConversation): ChatCompletionConversation
--- @field create_listed fun(conv: ChatCompletionConversation, name: string): ChatCompletionConversation
--- @field create_project fun(conv: ChatCompletionConversation, name: string, path: string?): ChatCompletionConversation
--- @field deserialize fun(conv: ChatCompletionConversation, data: table): ChatCompletionConversation
--- Member Methods
--- @field add_item fun(conv: ChatCompletionConversation, item: ChatCompletionMessage)
--- @field extend_last_item fun(conv: ChatCompletionConversation, delta: string)
--- @field can_remove_last_item fun(conv: ChatCompletionConversation): boolean
--- @field remove_last_item fun(conv: ChatCompletionConversation): boolean
--- @field prompt_response fun(conv: ChatCompletionConversation)
--- @field serialize fun(conv: ChatCompletionConversation): table
--- @field get_content fun(conv: ChatCompletionConversation): ConversationItem[]
--- @field is_ready fun(conv: ChatCompletionConversation): boolean
--- @field can_handle_text fun(conv: ChatCompletionConversation): boolean
--- @field handle_user_input_text fun(conv: ChatCompletionConversation, text: string): boolean
--- @field handle_text_context fun(conv: ChatCompletionConversation, context: string): boolean
--- @field set_agent fun(conv: ChatCompletionConversation, agent: string?)
--- Member Fields
--- @field content ChatCompletionMessage[]
--- @field agent string?
--- @field private _current_operation Future<any>?
local ChatCompletionConversation = Conversation.new_subclass("chat-completion")

function ChatCompletionConversation:new(name, path, agent)
	local new = Conversation.new(self, name, path) --[[@as ChatCompletionConversation]]
	new.content = {}
	new.agent = agent
	return new
end

function ChatCompletionConversation:create_unlisted()
	local new = self:new()
	return new
end

function ChatCompletionConversation:create_listed(name)
	local new = self:new(name)
	return new
end

function ChatCompletionConversation:create_project(name, path)
	local new = self:new(name, path)
	return new
end

function ChatCompletionConversation:deserialize(data)
	local conv = Conversation.deserialize(self, data) --[[@as ChatCompletionConversation]]
	local content = {}
	for i, item_data in ipairs(data.content) do
		content[i] = Item.deserialize_subclass(item_data)
	end
	conv.content = content
	conv.agent = data.agent
	return conv
end

function ChatCompletionConversation:add_item(item)
	table.insert(self.content, item)
	self:notify(function(obs)
		obs.on_new_item:dispatch({
			conversation = self,
			item = item,
		})
	end)
end

function ChatCompletionConversation:extend_last_item(delta)
	local index = #self.content
	local item = self.content[index]
	if item.role == "system" then
		error("Cannot extend system messages")
	end
	item.text = item.text .. delta
	self:notify(function(obs)
		obs.on_item_extended:dispatch({
			conversation = self,
			item = item,
			extension = delta,
		})
	end)
end

function ChatCompletionConversation:can_remove_last_item()
	return #self.content > 0
end

function ChatCompletionConversation:remove_last_item()
	if not self:can_remove_last_item() then
		return false
	end
	local index = #self.content
	local item = self.content[index]
	table.remove(self.content, index)
	self:notify(function(obs)
		obs.on_item_deleted:dispatch({
			conversation = self,
			item = item,
		})
	end)
	return true
end

function ChatCompletionConversation:prompt_response()
	assert(self:is_ready())

	local debouncer = Debouncer:new(function()
		return {}
	end, function(accumulator, new_element)
		table.insert(accumulator, new_element)
	end, function(accumulator)
		local text = vim.fn.join(accumulator, "")
		self:extend_last_item(text)
	end, 100)

	local request = Interface.post_streaming_request(self.agent, self.content, function(chunk)
		local delta = chunk.content
		if not chunk.role then
			if delta then
				debouncer:handle(delta)
				-- self:extend_last_item(delta)
			end
		else
			--- @type string?
			local name = Util.get_agent(self.agent).name
			if name == "" then
				name = nil
			end
			debouncer:push()
			self:add_item(Message:new(chunk.role, "assistant", delta or "", name))
		end
	end, function(_) end)
	if self:get_type() ~= "unlisted" then
		request.on_complete:subscribe(function(_)
			local ok, reason = IO.save_conversation(self)
			if not ok then
				vim.notify("Error while saving conversation: " .. reason, vim.log.levels.ERROR)
			end
			debouncer:close()
		end)
	end
	self._current_operation = request
end

function ChatCompletionConversation:serialize()
	local data = Conversation.serialize(self)
	local serialized_content = {}
	for i, item in ipairs(self.content) do
		serialized_content[i] = item:serialize()
	end
	data.content = serialized_content
	data.agent = self.agent
	return data
end

function ChatCompletionConversation:get_content()
	--- @type ChatCompletionSystemMessage
	local agent_prompt = SystemMessage:new(Util.get_agent(self.agent).system_message)
	--- @type ConversationItem[]
	local items = { agent_prompt }
	for i, item in ipairs(self.content) do
		items[i + 1] = item
	end
	return items
end

function ChatCompletionConversation:is_ready()
	return self._current_operation == nil or self._current_operation.completed
end

function ChatCompletionConversation:can_handle_text()
	return true
end

function ChatCompletionConversation:handle_user_input_text(text)
	if not self:is_ready() then
		return false
	end
	local message = Message:new("user", "user-input", text)
	self:add_item(message)
	return true
end

function ChatCompletionConversation:handle_text_context(context)
	if not self:is_ready() then
		return false
	end
	local message = Message:new("user", "user-context", context)
	self:add_item(message)
	return true
end

function ChatCompletionConversation:set_agent(new_agent)
	if self.agent == new_agent then
		return
	end
	self.agent = new_agent
	self:notify(function(obs)
		obs.on_conversation_update:dispatch({
			name = "option change",
			conversation = self,
		})
	end)
end

return ChatCompletionConversation
