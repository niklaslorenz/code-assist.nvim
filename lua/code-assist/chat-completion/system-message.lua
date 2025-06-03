local Item = require("code-assist.conversations.item")

--- @class ChatCompletionSystemMessage: ConversationItem
--- @field new fun(msg: ChatCompletionSystemMessage, text: string): ChatCompletionSystemMessage
--- @field serialize fun(msg: ChatCompletionSystemMessage): table
--- @field deserialize fun(msg: ChatCompletionSystemMessage, data: table): ChatCompletionSystemMessage
--- @field text string
local ChatCompletionSystemMessage = Item.new_subclass("chat-completion-system-message")

function ChatCompletionSystemMessage:new(text)
	local new = Item.new(self, "system") --[[@as ChatCompletionSystemMessage]]
	new.text = text
	return new
end

function ChatCompletionSystemMessage:serialize()
	local data = Item.serialize(self)
	data.text = self.text
	return data
end

function ChatCompletionSystemMessage:deserialize(data)
	local new = Item.deserialize(self, data) --[[@as ChatCompletionSystemMessage]]
	new.text = data.text
	return new
end

function ChatCompletionSystemMessage:get_channel_descriptor()
	return "System"
end

function ChatCompletionSystemMessage:print()
	return self.text
end

return ChatCompletionSystemMessage
