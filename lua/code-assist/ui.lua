-- Presents a floating buffer to pick an existing conversation

local M = {}
local cm = require("code-assist.conversation-manager")
local cw = require("code-assist.ui.chat-window")

function M.select_conversation(orientation)
	local convs = cm.list()
	if vim.tbl_isempty(convs) then
		vim.notify("No conversations found", vim.log.levels.WARN)
		return
	end

	-- Floating selection window
	local buf = vim.api.nvim_create_buf(false, true)
	local w = math.floor(vim.o.columns * 0.4)
	local h = math.floor(vim.o.lines * 0.4)
	local row = math.floor((vim.o.lines - h) / 2)
	local col = math.floor((vim.o.columns - w) / 2)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, convs)
	vim.bo[buf].modifiable = false

	-- Quit picker
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	-- Enter to load
	vim.keymap.set("n", "<CR>", function()
		local line = vim.api.nvim_win_get_cursor(win)[1]
		local name = convs[line]
		vim.api.nvim_win_close(win, true)
		local msgs = cm.load(name)
		if msgs then
			cw.open(name, msgs, orientation)
		else
			vim.notify("Failed to load conversation: " .. name, vim.log.levels.ERROR)
		end
	end, { buffer = buf })
end

return M
