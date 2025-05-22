local Path = {}

local Util = require("code-assist.util")
local Options = require("code-assist.options")

local last_conv_file_name = "last_conv.txt"
local project_config_dir_name = "config"

local listed_data_path = Options.data_path
local listed_conv_path = listed_data_path .. "/conversations"

--- Retrieve the path of a listed conversation.
--- If `conv_name` is not specified, then return the conversation directory instead.
--- @return string path
--- @param conv_name string?
function Path.get_listed_conversation_path(conv_name)
	if not conv_name then
		return listed_conv_path
	end
	return listed_conv_path .. "/" .. conv_name .. ".json"
end

--- @return string path
function Path.get_listed_config_path()
	return listed_data_path
end

--- @return string path
function Path.get_last_listed_conv_file_path()
	return listed_data_path .. "/" .. last_conv_file_name
end

--- Retrieve the path of a project conversation.
--- If `project_path` is not specified, use neo-tree's current directory.
--- If `conv_name` is not specified, return the conversation directory instead.
--- @param project_path string?
--- @param conv_name string?
--- @return string? path Return `nil` when there is no neo-tree directory and `project_path` is not specified.
function Path.get_project_conversation_path(project_path, conv_name)
	project_path = project_path or Util.get_current_neo_tree_path()
	if not project_path then
		return nil
	end
	local conversations_path = project_path .. "/" .. Options.project_conversation_path
	if not conv_name then
		return conversations_path
	else
		return conversations_path .. "/" .. conv_name .. ".json"
	end
end

--- @param project_path string?
--- @return string? path
function Path.get_project_config_path(project_path)
	local conversations_path = Path.get_project_conversation_path(project_path)
	if not conversations_path then
		return nil
	end
	return conversations_path .. "/" .. project_config_dir_name
end

--- @param project_path string?
--- @return string? path
function Path.get_last_project_conv_file_path(project_path)
	local config_path = Path.get_project_config_path(project_path)
	if not config_path then
		return nil
	end
	return config_path .. "/" .. last_conv_file_name
end

return Path
