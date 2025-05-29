local IO = {}

local Path = require("code-assist.conversations.path")
local Conversation = require("code-assist.conversations.conversation")
local Util = require("code-assist.util")

--- @param path string
local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

--- @param fname string
--- @return Conversation?
local function load_conversation(fname)
	local content = vim.fn.readfile(fname)
	local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
	if ok then
		return Conversation.deserialize_subclass(data)
	else
		return nil
	end
end

--- @param sorting ConversationSorting
--- @param path string
local function list_conversations(sorting, path)
	sorting = sorting or "newest"
	local files = vim.fn.readdir(path)
	local convs = {}
	for _, file in ipairs(files) do
		if file:match("%.json$") then
			local name = file:sub(1, -6)
			local mtime = vim.fn.getftime(path .. "/" .. file)
			table.insert(convs, { name = name, mtime = mtime })
		end
	end
	if sorting == "oldest" then
		table.sort(convs, function(a, b)
			return a.mtime < b.mtime
		end)
	elseif sorting == "newest" then
		table.sort(convs, function(a, b)
			return a.mtime > b.mtime
		end)
	elseif sorting == "name" then
		local temp = {}
		for i, conv in ipairs(convs) do
			temp[i] = { original = conv, lower_name = string.lower(conv.name) }
		end
		table.sort(temp, function(a, b)
			return a.lower_name < b.lower_name
		end)
		for i, v in ipairs(temp) do
			convs[i] = v.original
		end
	else
		error("Invalid sorting: " .. sorting)
	end
	local sorted_names = {}
	for _, conv in ipairs(convs) do
		table.insert(sorted_names, conv.name)
	end
	return sorted_names
end

--- @return string? name
function IO.get_last_listed_conv()
	local fname = Path.get_last_listed_conv_file_path()
	if vim.fn.filereadable(fname) == 0 then
		return nil
	end
	local lines = vim.fn.readfile(fname)
	local name = lines[1]
	return name
end

--- @nodiscard
--- @param name string
--- @return boolean ok, string? reason
function IO.set_last_listed_conv(name)
	local fname = Path.get_last_listed_conv_file_path()
	local dname = Path.get_listed_config_path()
	ensure_dir(dname)
	local ok = vim.fn.writefile({ name }, fname) == 0
	return ok, (not ok and "Error while writing file " .. fname or nil)
end

--- @param project_path string?
--- @return string?
function IO.get_last_project_conv(project_path)
	local fname = Path.get_last_project_conv_file_path(project_path)
	if not fname then
		return nil
	end
	if vim.fn.filereadable(fname) == 0 then
		return nil
	end
	local lines = vim.fn.readfile(fname)
	local name = lines[1]
	return name
end

--- @nodiscard
--- @param name string
--- @param project_path string?
--- @return boolean ok, string? reason
function IO.set_last_project_conv(name, project_path)
	local fname = Path.get_last_project_conv_file_path(project_path)
	local dname = Path.get_project_config_path(project_path)
	if not fname or not dname then
		return false, "Could not get project path"
	end
	ensure_dir(dname)
	local ok = vim.fn.writefile({ name }, fname) == 0
	return ok, (not ok and "Error whilte writing file " .. fname or nil)
end

--- @param conv_name string
--- @return Conversation? conversation
function IO.load_listed_conversation(conv_name)
	local fname = Path.get_listed_conversation_path(conv_name)
	if vim.fn.filereadable(fname) == 0 then
		return nil
	end
	local conv = load_conversation(fname)
	conv.name = conv_name
	conv.project_path = nil
	return conv
end

--- @param conv_name string
--- @param project_path string?
--- @return Conversation? conversation
function IO.load_project_conversation(conv_name, project_path)
	local fname = Path.get_project_conversation_path(project_path, conv_name)
	if not fname or vim.fn.filereadable(fname) == 0 then
		return nil
	end
	local conv = load_conversation(fname)
	conv.name = conv_name
	conv.project_path = project_path or Util.get_current_neo_tree_path()
	return conv
end

--- @nodiscard
--- @param conv Conversation
--- @return boolean ok, string? reason
function IO.save_conversation(conv)
	local fname = conv:get_path()
	if not fname then
		return false, "Could not find file path"
	end
	ensure_dir(vim.fn.fnamemodify(fname, ":h"))
	if not Util.can_write(fname) then
		return false, "Cannot write to file: " .. fname
	end
	local data = vim.json.encode(conv:serialize())
	vim.fn.writefile({ data }, fname)
	return true, nil
end

--- @return Conversation? conv
function IO.load_last_listed_conversation()
	local last_listed = IO.get_last_listed_conv()
	if not last_listed then
		return nil
	end
	return IO.load_listed_conversation(last_listed)
end

--- @param project_path string?
--- @return Conversation? conv
function IO.load_last_project_conversation(project_path)
	local last_project = IO.get_last_project_conv(project_path)
	if not last_project then
		return nil
	end
	return IO.load_project_conversation(last_project, project_path)
end

--- @param project_path string?
--- @return Conversation? conv
function IO.load_last(project_path)
	local conv = IO.load_last_project_conversation(project_path)
	if conv then
		return conv
	end
	return IO.load_last_listed_conversation()
end

--- @param project_path string?
--- @return Conversation? conv
function IO.load_last_or_create_new(project_path)
	local conv = IO.load_last(project_path)
	if conv then
		return conv
	end
	return Util.get_default_conversation_class():create_unlisted()
end

local function rename(fname, new_fname)
	if not fname or vim.fn.filereadable(fname) == 0 then
		return false, "Could not find conversation file"
	end
	if vim.fn.filereadable(new_fname) then
		return false, "Target already exists"
	end
	local success = vim.fn.rename(fname, new_fname) == 0
	local reason = not success and "Error renaming file" or nil
	return success, reason
end

--- @nodiscard
--- @param conv Conversation
--- @param new_name string
--- @return boolean ok, string? reason
function IO.rename_conversation(conv, new_name)
	local fname = conv:get_path()
	local new_fname = conv.project_path and Path.get_project_conversation_path(conv.project_path, new_name)
			or Path.get_listed_conversation_path(new_name)
	return rename(fname, new_fname)
end

--- @nodiscard
--- @param name string
--- @param new_name string
--- @return boolean ok, string? reason
function IO.rename_listed_conversation(name, new_name)
	local fname = Path.get_listed_conversation_path(name)
	local new_fname = Path.get_listed_conversation_path(new_name)
	return rename(fname, new_fname)
end

--- @nodiscard
--- @param name string
--- @param new_name string
--- @param project_path string?
--- @return boolean ok, string? reason
function IO.rename_project_conversation(name, new_name, project_path)
	local fname = Path.get_project_conversation_path(project_path, name)
	local new_fname = Path.get_project_conversation_path(project_path, new_name)
	return rename(fname, new_fname)
end

local function delete(fname)
	if not fname or vim.fn.filereadable(fname) == 0 then
		return false, "Could not find conversation file"
	end
	local success = vim.fn.delete(fname) == 0
	local reason = (not success) and "Error deleting conversation file" or nil
	return success, reason
end

--- @nodiscard
--- @param conv Conversation
--- @return boolean ok, string? reason
function IO.delete_conversation(conv)
	local fname = conv:get_path()
	return delete(fname)
end

--- @nodiscard
--- @param name string
--- @return boolean ok, string? reason
function IO.delete_listed_conversation(name)
	local fname = Path.get_listed_conversation_path(name)
	return delete(fname)
end

--- @nodiscard
--- @param name string
--- @param project_path string?
--- @return boolean ok, string? reason
function IO.delete_project_conversation(name, project_path)
	local fname = Path.get_project_conversation_path(project_path, name)
	return delete(fname)
end

--- @param sorting ConversationSorting
--- @return string[] names
function IO.list_listed_conversations(sorting)
	local conv_path = Path.get_listed_conversation_path()
	return list_conversations(sorting, conv_path)
end

--- @param sorting ConversationSorting
--- @param path string?
--- @return string[] names
function IO.list_project_conversations(sorting, path)
	local conv_path = Path.get_project_conversation_path(path)
	if not conv_path then
		vim.notify("Could not find project path", vim.log.levels.WARN)
		return {}
	end
	return list_conversations(sorting, conv_path)
end

return IO
