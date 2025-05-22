--- @class ConversationItem
--- Static Methods
--- @field deserialize_subclass fun(data: table): ConversationItem
--- @field deserialize fun(item: ConversationItem, data: table): ConversationItem
--- @field new fun(item: ConversationItem, role: ConversationRole, channel: ConversationChannel): ConversationItem
--- Static Attributes
--- @field protected _type ConversationItemClass
--- Member Methods
--- @field is fun(item: ConversationItem, item2: ConversationItem): boolean
--- @field get_type fun(item: ConversationItem): ConversationItemClass
--- @field print fun(item: ConversationItem): string?
--- @field serialize fun(item: ConversationItem): table
--- Member Attributes
--- @field role ConversationRole
--- @field channel ConversationChannel
local ConversationItem = {}
ConversationItem.__index = ConversationItem
ConversationItem._type = "item"

function ConversationItem:get_type()
	return self._type
end

function ConversationItem:is(item2)
	return self._type == item2._type
end

function ConversationItem:new(role, channel)
	local new = {
		role = role,
		channel = channel,
	}
	setmetatable(new, self)
	return new
end

function ConversationItem.deserialize_subclass(data)
	local type = data.type --[[@as ConversationItemClass]]
	if type == "message" then
		return require("code-assist.conversations.message"):deserialize(data)
	elseif type == "item" then
		error("Cannot deserialize a conversation item of the abstract type 'item'")
	else
		error("Unknown conversation item class: " .. (type or "nil"))
	end
end

function ConversationItem:deserialize(data)
	assert(self._type == data.type, "Tried to deserialize the wrong item class.")
	local deserialized = {
		role = data.role,
		channel = data.channel,
	}
	setmetatable(deserialized, self)
	return deserialized
end

function ConversationItem:print()
	return nil
end

function ConversationItem:serialize()
	local data = {
		type = self._type,
		role = self.role,
		channel = self.channel,
	}
	return data
end

return ConversationItem
