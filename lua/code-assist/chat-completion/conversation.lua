local Conversation = require("code-assist.conversations.conversation")
local Item = require("code-assist.conversations.item")

--- @class ChatCompletionConversation: Conversation
--- Static Methods
--- @field new fun(conv: ChatCompletionConversation, name: string?, path: string?): ChatCompletionConversation
--- Class Methods
--- @field deserialize fun(conv: ChatCompletionConversation, data: table): ChatCompletionConversation
--- Member Methods
--- @field add_item fun(conv: ChatCompletionConversation, item: ChatCompletionMessage)
--- @field serialize fun(conv: ChatCompletionConversation): table
--- @field get_content fun(conv: ChatCompletionConversation): ConversationItem[]
--- Member Fields
--- @field content ChatCompletionMessage[]
local ChatCompletionConversation = Conversation.new_subclass("chat-completion")

function ChatCompletionConversation:new(name, path)
	local new = Conversation.new(self, name, path) --[[@as ChatCompletionConversation]]
	self.content = {}
	return new
end

function ChatCompletionConversation:add_item(item)
	table.insert(self.content, item)
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

function ChatCompletionConversation:serialize()
	local data = Conversation.serialize(self)
	local serialized_content = {}
	for i, item in ipairs(self.content) do
		serialized_content[i] = item:serialize()
	end
	data.content = serialized_content
	return data
end

return ChatCompletionConversation
