local SelectWindow = {}

local ConversationManager = require("code-assist.conversation-manager")
local ChatWindow = require("code-assist.ui.chat-window")

--- @type integer | nil
local select_win = nil

--- @type integer | nil
local select_buf = nil

--- @type string[]
local conv_list = {}

local function get_win()
	if select_win and vim.api.nvim_win_is_valid(select_win) then
		return select_win
	end
	return nil
end

local function get_buf()
	if select_buf and vim.api.nvim_buf_is_valid(select_buf) then
		return select_buf
	end
	return nil
end

--- Get the name of the hovered conversation.
--- @return string name
local function get_hovered()
	local win = get_win()
	assert(win)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	return conv_list[line]
end

local function select_hovered()
	local name = get_hovered()
	local success = ConversationManager.load_conversation(name)
	if success then
		SelectWindow.close()
		ChatWindow.open()
	else
		vim.notify("Failed to load conversation: " .. name, vim.log.levels.ERROR)
	end
end

local function delete_hovered()
	local name = get_hovered()
	vim.ui.input({ prompt = "Delete " .. name .. "?" }, function(input)
		if not input or input ~= "yes" then
			return
		end
		local success = ConversationManager.delete_conversation(name)
		if not success then
			vim.notify("Failed to delete conversation: " .. name, vim.log.levels.ERROR)
		end
		SelectWindow.refresh()
	end)
end

local function rename_hovered()
	local name = get_hovered()
	vim.ui.input({ prompt = "Rename", default = name }, function(input)
		if not input then
			return
		end
		local success = ConversationManager.rename_conversation(name, input)
		if not success then
			vim.notify("Failed to rename conversation: " .. name, vim.log.levels.ERROR)
		end
		SelectWindow.refresh()
	end)
end

local function setup_keymaps()
	local win = get_win()
	local buf = get_buf()
	assert(win)
	assert(buf)

	-- Quit
	vim.keymap.set("n", "q", function()
		SelectWindow.close()
	end, { buffer = buf })

	-- Enter to load
	vim.keymap.set("n", "<CR>", function()
		select_hovered()
	end, { buffer = buf })

	vim.keymap.set("n", "d", function()
		delete_hovered()
	end, { buffer = buf })

	vim.keymap.set("n", "r", function()
		rename_hovered()
	end, { buffer = buf })
	return true
end

function SelectWindow.close()
	local win = get_win()
	if win then
		vim.api.nvim_win_close(win, true)
		select_win = nil
	end
	local buf = get_buf()
	if buf then
		vim.api.nvim_buf_delete(buf, { force = true })
		select_buf = nil
	end
end

function SelectWindow.open()
	local win = get_win()
	if win then
		vim.api.nvim_set_current_win(win)
		return
	end
	select_buf = vim.api.nvim_create_buf(false, true)
	local w = math.floor(vim.o.columns * 0.4)
	local h = math.floor(vim.o.lines * 0.4)
	local row = math.floor((vim.o.lines - h) / 2)
	local col = math.floor((vim.o.columns - w) / 2)
	select_win = vim.api.nvim_open_win(select_buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.bo[select_buf].buftype = "nofile"
	vim.bo[select_buf].filetype = "markdown"
	vim.bo[select_buf].swapfile = false
	vim.bo[select_buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(select_buf, 0, -1, false, conv_list)
	vim.bo[select_buf].modifiable = false
	setup_keymaps()
	SelectWindow.refresh()
end

function SelectWindow.refresh()
	local buf = get_buf()
	assert(buf)
	conv_list = ConversationManager.list_conversations()
	if vim.tbl_isempty(conv_list) then
		vim.notify("No conversations found", vim.log.levels.INFO)
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, conv_list)
	vim.bo[buf].modifiable = false
end

return SelectWindow
