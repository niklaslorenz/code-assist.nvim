local Path = require("code-assist.conversations.path")
local Util = require("code-assist.util")

--- @class Conversation
--- Static Methods
--- @field new_subclass fun(class_name: string): Conversation
--- @field deserialize_subclass fun(data: table): Conversation
--- Class Methods
--- @field deserialize fun(conv: Conversation, data: table): Conversation
--- @field new fun(conv: Conversation, name: string?, path: string?): Conversation
--- @field create_unlisted fun(conv: Conversation): Conversation
--- @field create_listed fun(conv: Conversation, name: string): Conversation
--- @field create_project fun(conv: Conversation, name: string, path: string?): Conversation
--- @field get_class fun(conv: Conversation): string
--- Member Methods
--- @field serialize fun(conv: Conversation): table
--- @field get_type fun(conv: Conversation): ConversationType
--- @field get_path fun(conv: Conversation): string?
--- @field get_content fun(conv: Conversation): ConversationItem[]
--- @field is_ready fun(conv: Conversation): boolean
--- @field can_handle_text fun(conv: Conversation): boolean
--- @field handle_text_context fun(conv: Conversation, context: string): boolean
--- @field handle_user_input_text fun(conv: Conversation, text: string): boolean
--- @field can_remove_last_item fun(conv: Conversation): boolean
--- @field remove_last_item fun(conv: Conversation): boolean
--- @field prompt_response fun(conv: Conversation)
--- @field add_observer fun(conv: Conversation, obs: ConversationObserver)
--- @field remove_observer fun(conv: Conversation, obs: ConversationObserver)
--- @field unload fun(conv: Conversation)
--- @field protected notify fun(conv: Conversation, callback: fun(obs: ConversationObserver))
--- Static Attributes
--- @field protected _class string
--- @field private _subclasses table<string, Conversation>
--- Member Attributes
--- @field name string?
--- @field project_path string?
--- @field private _observers ConversationObserver[]
local Conversation = {}
Conversation.__index = Conversation
Conversation._class = "base"
Conversation._subclasses = { "base" }

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

--- @diagnostic disable: unused-local
function Conversation:deserialize(data)
	local new = {
		_observers = {},
	}
	setmetatable(new, self)
	return new
end

function Conversation:new(name, project_path)
	local new = {
		name = name,
		project_path = project_path,
		_observers = {},
	}
	setmetatable(new, self)
	return new
end

function Conversation:create_unlisted()
	return self:new()
end

function Conversation:create_listed(name)
	return self:new(name)
end

function Conversation:create_project(name, path)
	return self:new(name, path)
end

function Conversation:get_class()
	return self._class
end

function Conversation:serialize()
	local data = {
		class = self._class,
	}
	return data
end

function Conversation:can_handle_text()
	return false
end

function Conversation:handle_user_input_text()
	return false
end

function Conversation:handle_text_context(context)
	return false
end

function Conversation:can_remove_last_item()
	return false
end

function Conversation:remove_last_item()
	return false
end

function Conversation:get_content()
	error("subclasses are expected to override this function")
end

function Conversation:is_ready()
	error("subclasses are expected to override this function")
end

function Conversation:prompt_response()
	error("subclasses are expected to override this function")
end

function Conversation:add_observer(obs)
	local inserted = Util.set_insert(self._observers, obs)
	if not inserted then
		vim.notify("Observer already in observer list", vim.log.levels.WARN)
	end
end

function Conversation:remove_observer(obs)
	local removed = Util.set_remove(self._observers, obs)
	if not removed then
		vim.notify("Observer not in the observer list", vim.log.levels.WARN)
	end
end

function Conversation:unload() end

function Conversation:notify(callback)
	for _, obs in ipairs(self._observers) do
		callback(obs)
	end
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
