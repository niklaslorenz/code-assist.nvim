local Path = require("code-assist.conversations.path")

--- @class Conversation
--- Static Methods
--- @field new_subclass fun(class_name: string): Conversation
--- @field deserialize_subclass fun(data: table): Conversation
--- Class Methods
--- @field deserialize fun(conv: Conversation, data: table): Conversation
--- @field new fun(conv: Conversation, name: string?, path: string?): Conversation
--- Member Methods
--- @field serialize fun(conv: Conversation): table
--- @field get_type fun(conv: Conversation): ConversationType
--- @field get_path fun(conv: Conversation): string?
--- @field get_content fun(conv: Conversation): ConversationItem[]
--- Static Attributes
--- @field protected _class string
--- @field private _subclasses table<string, Conversation>
--- Member Attributes
--- @field name string?
--- @field project_path string?
local Conversation = {}
Conversation.__index = Conversation
Conversation._class = "base"

function Conversation.new_subclass(class_name)
	local class = {}
	class.__index = class
	class._class = class_name
	setmetatable(class, Conversation)
	Conversation._subclasses[class_name] = class
	return class
end

function Conversation.deserialize_subclass(data)
	local class_name = data.class
	if not class_name then
		error("undefined subclass in input data")
	end
	local class = Conversation._subclasses[class_name]
	if not class then
		error("Unknown conversation item subclass: " .. class_name)
	end
	if class == "base" then
		error("Cannot deserialize abstract conversation class 'base'")
	end
	return class:deserialize(data)
end

function Conversation:deserialize(data)
	local new = {}
	setmetatable(new, self)
	return new
end

function Conversation:new(name, project_path)
	local new = {
		name = name,
		project_path = project_path,
	}
	setmetatable(new, self)
	return new
end

function Conversation:serialize()
	local data = {
		class = self._class,
	}
	return data
end

function Conversation:get_content()
	error("subclasses are expected to override this function")
end

function Conversation:get_type()
	if not self.name then
		return "unlisted"
	elseif not self.project_path then
		return "listed"
	else
		return "project"
	end
end

function Conversation:get_path()
	local type = self:get_type()
	if type == "unlisted" then
		return nil
	end
	if type == "listed" then
		return Path.get_listed_conversation_path(self.name)
	elseif type == "project" then
		return Path.get_project_conversation_path(self.project_path, self.name)
	end
	error("Unknown conversation type: " .. type)
end

return Conversation
