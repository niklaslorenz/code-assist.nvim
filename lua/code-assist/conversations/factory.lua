local Factory = {}

local Message = require("code-assist.conversations.message")
local Conversation = require("code-assist.conversations.conversation")
local Options = require("code-assist.options")
local Util = require("code-assist.util")

function Factory.new_initial_system_message()
	return Message:new("system", "system", Options.system_message)
end

--- @return Conversation
function Factory.new_unlisted_conversation()
	local system_message = Factory.new_initial_system_message()
	local conversation = Conversation:new()
	table.insert(conversation.content, system_message)
	return conversation
end

--- @param name string
--- @return Conversation
function Factory.new_listed_conversation(name)
	local system_message = Factory.new_initial_system_message()
	local conversation = Conversation:new(name)
	table.insert(conversation.content, system_message)
	return conversation
end

--- @param name string
--- @param project_path string?
--- @return Conversation
function Factory.new_project_conversation(name, project_path)
	local system_message = Factory.new_initial_system_message()
	local conversation = Conversation:new(name, project_path or Util.get_current_neo_tree_path())
	table.insert(conversation.content, system_message)
	return conversation
end

return Factory
