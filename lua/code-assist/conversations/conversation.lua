local Path = require("code-assist.conversations.path")
local ConversationItem = require("code-assist.conversations.item")

--- @class Conversation
--- Static Methods
--- @field deserialize fun(conv: Conversation, data: table): Conversation
--- @field new fun(conv: Conversation, name: string?, path: string?): Conversation
--- Member Methods
--- @field serialize fun(conv: Conversation): table
--- @field get_type fun(conv: Conversation): ConversationType
--- @field get_path fun(conv: Conversation): string?
--- Attributes
--- @field name string?
--- @field project_path string?
--- @field content ConversationItem[]
local Conversation = {}
Conversation.__index = Conversation

function Conversation:new(name, project_path)
	local new = {
		name = name,
		project_path = project_path,
		content = {},
	}
	setmetatable(new, self)
	return new
end

function Conversation:deserialize(data)
	--- @type ConversationItem[]
	local content = {}
	for i, item in ipairs(data.content) do
		content[i] = ConversationItem.deserialize_subclass(item)
	end
	local new = {
		content = content,
	}
	setmetatable(new, self)
	return new
end

function Conversation:serialize()
	local content = {}
	for i, item in ipairs(self.content) do
		content[i] = item:serialize()
	end
	local data = {
		content = content,
	}
	return data
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
