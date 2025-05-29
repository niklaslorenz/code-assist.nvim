local Item = require("code-assist.conversations.item")

--- @class ChatCompletionMessage: ConversationItem
--- @field new fun(msg: ChatCompletionMessage, role: ChatCompletionRole, channel: string, text: string): ChatCompletionMessage
--- @field serialize fun(msg: ChatCompletionMessage): table
--- @field deserialize fun(msg: ChatCompletionMessage, data: table): ChatCompletionMessage
--- @field role ChatCompletionRole
--- @field text string
--- @field channel "user-input"|
local ChatCompletionMessage = Item.new_subclass("chat-completion-message")

function ChatCompletionMessage:new(role, channel, text)
	local new = Item.new(self, channel) --[[@as ChatCompletionMessage]]
	new.role = role
	new.text = text
	return new
end

function ChatCompletionMessage:serialize()
	local data = Item.serialize(self)
	data.role = self.role
	data.text = self.text
	return data
end

function ChatCompletionMessage:deserialize(data)
	local new = Item.deserialize(self, data) --[[@as ChatCompletionMessage]]
	new.role = data.role
	new.text = data.text
	return new
end

function ChatCompletionMessage:get_user_descriptor()
	if self.role == "system" then
		return "System"
	elseif self.role == "user" then
		return "User"
	elseif self.role == "assistant" then
		return "Assistant"
	end
	error("Unknown role: " .. self.role)
end

function ChatCompletionMessage:print()
	return self.text
end

return ChatCompletionMessage
