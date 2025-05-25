local Item = require("code-assist.conversations.item")

--- @class ChatCompletionMessage: ConversationItem
--- @field new fun(msg: ChatCompletionMessage, role: ChatCompletionRole, channel: string, text: string): ChatCompletionMessage
--- @field serialize fun(msg: ChatCompletionMessage): table
--- @field deserialize fun(msg: ChatCompletionMessage, data: table): ChatCompletionMessage
--- @field role ChatCompletionRole
--- @field text string
local ChatCompletionMessage = Item.new_subclass("chat-completion-message")

function ChatCompletionMessage:new(role, channel, text)
	local new = Item.new(self, channel) --[[@as ChatCompletionMessage]]
	new.role = role
	new.text = text
	return new
end

function ChatCompletionMessage:serialize()
	local data = Item.serialize(self)
	data.text = self.text
	data.role = self.role
	return data
end

function ChatCompletionMessage:deserialize(data)
	local new = Item.deserialize(self, data) --[[@as ChatCompletionMessage]]
	new.text = data.text
	new.role = data.role
	return new
end
