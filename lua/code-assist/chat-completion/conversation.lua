local Message = require("code-assist.chat-completion.message")
local Options = require("code-assist.options")
local Conversation = require("code-assist.conversations.conversation")
local Item = require("code-assist.conversations.item")
local Interface = require("code-assist.api.chat-completion")
local Debouncer = require("code-assist.debouncer")
local IO = require("code-assist.conversations.io")

--- @class ChatCompletionConversation: Conversation
--- Static Methods
--- @field new fun(conv: ChatCompletionConversation, name: string?, path: string?): ChatCompletionConversation
--- Class Methods
--- @field deserialize fun(conv: ChatCompletionConversation, data: table): ChatCompletionConversation
--- Member Methods
--- @field add_item fun(conv: ChatCompletionConversation, item: ChatCompletionMessage)
--- @field extend_last_item fun(conv: ChatCompletionConversation, delta: string)
--- @field prompt_response fun(conv: ChatCompletionConversation)
--- @field serialize fun(conv: ChatCompletionConversation): table
--- @field get_content fun(conv: ChatCompletionConversation): ConversationItem[]
--- Member Fields
--- @field content ChatCompletionMessage[]
--- @field private _current_operation Future<any>?
local ChatCompletionConversation = Conversation.new_subclass("chat-completion")

function ChatCompletionConversation:new(name, path)
	local new = Conversation.new(self, name, path) --[[@as ChatCompletionConversation]]
	self.content = {}
	return new
end

function ChatCompletionConversation:create_unlisted()
	local new = self:new()
	local system_message = Message:new("system", "system", Options.system_message)
	new:add_item(system_message)
	return new
end

function ChatCompletionConversation:create_listed(name)
	local new = self:new(name)
	local system_message = Message:new("system", "system", Options.system_message)
	new:add_item(system_message)
	return new
end

function ChatCompletionConversation:create_project(name, path)
	local new = self:new(name, path)
	local system_message = Message:new("system", "system", Options.system_message)
	new:add_item(system_message)
	return new
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

function ChatCompletionConversation:extend_last_item(delta)
	local index = #self.content
	local item = self.content[index]
	item.text = item.text .. delta
	self:notify(function(obs)
		obs.on_item_extended:dispatch({
			conversation = self,
			item = item,
			extension = delta,
		})
	end)
end

function ChatCompletionConversation:deserialize(data)
	local conv = Conversation.deserialize(self, data) --[[@as ChatCompletionConversation]]
	local content = {}
	for i, item_data in ipairs(data.content) do
		content[i] = Item.deserialize_subclass(item_data)
	end
	conv.content = content
	return conv
end

function ChatCompletionConversation:prompt_response()
	assert(self:is_ready())

	--[[
	local debouncer = Debouncer:new(function()
		return {}
	end, function(accumulator, new_element)
		table.insert(accumulator, new_element)
	end, function(accumulator)
		local text = vim.fn.join(accumulator)
		self:extend_last_item(text)
	end, 250)
	]]

	local request = Interface.post_streaming_request(Options.model, self.content, function(chunk)
		local delta = chunk.content
		if not chunk.role then
			if delta then
				self:extend_last_item(delta)
			end
		else
			self:add_item(Message:new(chunk.role, "assistant", delta or ""))
		end
	end, function(_) end)
	if self:get_type() ~= "unlisted" then
		request.on_complete:subscribe(function(_)
			local ok, reason = IO.save_conversation(self)
			if not ok then
				vim.notify("Error while saving conversation: " .. reason, vim.log.levels.ERROR)
			end
		end)
	end
	self._current_operation = request
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

function ChatCompletionConversation:serialize()
	local data = Conversation.serialize(self)
	local serialized_content = {}
	for i, item in ipairs(self.content) do
		serialized_content[i] = item:serialize()
	end
	data.content = serialized_content
	return data
end

function ChatCompletionConversation:get_content()
	return self.content
end

return ChatCompletionConversation
