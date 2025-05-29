--- @class ConversationItem
--- Static Methods
--- @field deserialize_subclass fun(data: table): ConversationItem
--- @field new_subclass fun(class_name: string): ConversationItem
--- Class Methods
--- @field deserialize fun(item: ConversationItem, data: table): ConversationItem
--- @field new fun(item: ConversationItem, channel: string): ConversationItem
--- Member Methods
--- @field print fun(item: ConversationItem): string?
--- @field serialize fun(item: ConversationItem): table
--- @field get_user_descriptor fun(item: ConversationItem): string
--- Static Attributes
--- @field protected _class string
--- @field private _subclasses table<string, ConversationItem>
--- Member Attributes
--- @field channel string
local ConversationItem = {}
ConversationItem.__index = ConversationItem
ConversationItem._class = "item"
ConversationItem._subclasses = { [ConversationItem._class] = ConversationItem }

function ConversationItem.new_subclass(class_name)
	local class = {}
	class.__index = class
	class._class = class_name
	setmetatable(class, ConversationItem)
	ConversationItem._subclasses[class_name] = class
	return class
end

function ConversationItem:new(channel)
	local new = {
		channel = channel,
	}
	setmetatable(new, self)
	return new
end

function ConversationItem.deserialize_subclass(data)
	local class_name = data.class
	if not class_name then
		error("undefined subclass in input data")
	end
	local class = ConversationItem._subclasses[class_name]
	if not class then
		error("Unknown conversation item subclass: " .. class_name)
	end
	if class == "item" then
		error("Cannot deserialize abstract item class 'item'")
	end
	return class:deserialize(data)
end

function ConversationItem:deserialize(data)
	assert(self._class == data.class, "Tried to deserialize the wrong item class.")
	local deserialized = {
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
		class = self._class,
		channel = self.channel,
	}
	return data
end

function ConversationItem:get_user_descriptor()
	return self.channel
end

return ConversationItem
