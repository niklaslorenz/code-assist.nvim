local Item = require("code-assist.conversations.item")

--- @class ConversationMessage : ConversationItem
--- @field protected _type ConversationItemClass
--- @field new fun(msg: ConversationMessage, role: ConversationRole, channel: ConversationChannel, content: string): ConversationMessage
--- @field print fun(msg: ConversationMessage): string
--- @field content string
local Message = {}
Message.__index = Message
setmetatable(Message, Item)
Message._type = "message"

function Message:new(role, channel, content)
	local new = Item.new(self, role, channel) --[[@as ConversationMessage]]
	new.content = content
	return new
end

function Message:print()
	return self.content
end

function Message:serialize()
	local data = Item.serialize(self)
	data.content = self.content
	return data
end

function Message:deserialize(data)
	local deserialized = Item.deserialize(self, data) --[[@as ConversationMessage]]
	deserialized.content = data.content
	return deserialized
end

return Message
