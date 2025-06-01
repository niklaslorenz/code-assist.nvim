local Util = {}

local Options = require("code-assist.options")

local has_whichkey, WhichKey = pcall(require, "which-key")
local has_neo_tree, NeoTreeManager = pcall(require, "neo-tree.sources.manager")

function Util.project_conversations_enabled()
	return has_neo_tree and Options.project_conversation_path ~= nil
end

--- @return string
function Util.get_default_agent_prompt()
	if Options.default_agent then
		return Util.get_agent_prompt(Options.default_agent) or Options.default_system_message
	end
	return Options.default_system_message
end

--- @return string[]
function Util.get_agent_names()
	local names = {}
	for name, _ in pairs(Options.agents) do
		table.insert(names, name)
	end
	return names
end

--- @param name string
--- @return string?
function Util.get_agent_prompt(name)
	return name and Options.agents[name] or Util.get_default_agent_prompt()
end

--- @return string
function Util.get_default_model_name()
	local name = Options.default_model
	if not name then
		error("Could not find default model")
	end
	return name
end

--- @return string[]
function Util.get_available_model_names()
	local names = {}
	for name, _ in pairs(Options.models) do
		table.insert(names, name)
	end
	return names
end

--- @param name string
--- @return string?
function Util.get_model_id(name)
	return Options.models[name]
end

function Util.get_default_conversation_class()
	if Options.default_conversation_class == "chat-completion" then
		return require("code-assist.chat-completion.conversation")
	elseif Options.default_conversation_class == "assistant" then
		return require("code-assist.assistant.conversation")
	else
		error("Unknown conversation class: " .. Options.default_conversation_class)
	end
end

--- @param list any[]
--- @param item any
--- @return integer
function Util.list_find(list, item)
	for i, value in ipairs(list) do
		if value == item then
			return i
		end
	end
	return -1
end

--- @param list any[]
--- @param item any
--- @return boolean
function Util.list_contains(list, item)
	return Util.list_find(list, item) ~= -1
end

--- @param set any[]
--- @param item any
--- @return boolean inserted If the item was actually inserted into the set
function Util.set_insert(set, item)
	if Util.list_contains(set, item) then
		return false
	end
	table.insert(set, item)
	return true
end

--- @param set any[]
--- @param item any
--- @return boolean removed If the item was actually removed
function Util.set_remove(set, item)
	local index = Util.list_find(set, item)
	if index ~= -1 then
		table.remove(set, index)
		return true
	end
	return false
end

--- @param path string
--- @return boolean
function Util.can_write(path)
	local status = vim.fn.filewritable(path)
	if status == 0 then
		local dir = vim.fn.fnamemodify(path, ":h")
		return vim.fn.filewritable(dir) == 2
	elseif status == 1 then
		return true
	end
	error("Unreachable")
end

--- @param lhs string
--- @param rhs fun()|string?
--- @param description string?
--- @param opts vim.keymap.set.Opts?
--- @param mode string|string[]?
function Util.set_keymap(lhs, rhs, description, opts, mode)
	if not opts then
		opts = {}
	end
	if not mode then
		mode = "n"
	end
	if has_whichkey then
		local f = type(rhs) == "function" and rhs or nil
		local s = type(rhs) == "string" and rhs or nil
		--- @type wk.Spec
		local mapping = {
			{
				mode = mode,
				callback = f,
				lhs = lhs,
				desc = description,
				rhs = s,
			},
		}
		for k, v in pairs(opts) do
			mapping[k] = v
		end
		WhichKey.add(mapping)
	elseif rhs then
		vim.keymap.set(mode, lhs, rhs, opts)
	end
end

function Util.get_current_neo_tree_path()
	if NeoTreeManager then
		return NeoTreeManager.get_state("filesystem").path
	else
		return nil
	end
end

function Util.get_temp_path()
	return Options.data_path .. "/tmp"
end

function Util.get_current_selection()
	local mode = vim.fn.mode()
	local start_pos, end_pos

	if mode == "v" or mode == "V" then
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")
	else
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
	end

	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local start_col = start_pos[3]
	local end_col = end_pos[3]

	if start_line > end_line then
		local x = start_line
		start_line = end_line
		end_line = x
		x = start_col
		start_col = end_col
		end_col = x
	end

	local selected_lines = {}

	if mode == "v" then
		-- Character-wise selection
		for line_num = start_line, end_line do
			local line = vim.fn.getline(line_num)
			if line_num == start_line and line_num == end_line then
				table.insert(selected_lines, line:sub(start_col, end_col))
			elseif line_num == start_line then
				table.insert(selected_lines, line:sub(start_col))
			elseif line_num == end_line then
				table.insert(selected_lines, line:sub(1, end_col))
			else
				table.insert(selected_lines, line)
			end
		end
	elseif mode == "V" then
		-- Line-wise selection
		for line_num = start_line, end_line do
			table.insert(selected_lines, vim.fn.getline(line_num))
		end
	end
	local selection = table.concat(selected_lines, "\n")
	return selection
end

return Util
