-- Renders the floating chat buffer and handles I/O with OpenAI

local model = "gpt-4o-mini"

local M = {}
local cm = require("code-assist.conversation-manager")

local chat_buf, chat_win, messages, conv_name

local ns = vim.api.nvim_create_namespace("code-assist")

local function eventListener() end
local function append_message(role, content)
	vim.bo[chat_buf].modifiable = true

	local header = (role == "user" and "You:" or "Assistant:")
	local line_count = vim.api.nvim_buf_line_count(chat_buf)
	vim.api.nvim_buf_set_lines(chat_buf, line_count, line_count, false, { header })

	local h1_group = (role == "user" and "ChatUser" or "ChatAssistant")
	vim.api.nvim_buf_add_highlight(chat_buf, ns, h1_group, line_count, 0, -1)

	local body_lines = {}
	for _, ln in ipairs(vim.split(content, "\n")) do
		table.insert(body_lines, "  " .. ln)
	end
	vim.api.nvim_buf_set_lines(chat_buf, line_count + 1, line_count + 1, false, body_lines)

	vim.api.nvim_win_set_cursor(chat_win, { vim.api.nvim_buf_line_count(chat_buf), 0 })

	vim.bo[chat_buf].modifiable = false
end

function M.open(name, msgs, orientation)
	conv_name = name
	messages = msgs

	-- If already open, jump there
	if chat_win and vim.api.nvim_win_is_valid(chat_win) then
		vim.api.nvim_set_current_win(chat_win)
		return
	end

	chat_buf = vim.api.nvim_create_buf(false, true)
	if orientation == "horizontal" then
		vim.cmd("split")
		chat_win = vim.api.nvim_get_current_win()
	elseif orientation == "vertical" then
		vim.cmd("vsplit")
		chat_win = vim.api.nvim_get_current_win()
	else
		local w = math.floor(vim.o.columns * 0.6)
		local h = math.floor(vim.o.lines * 0.6)
		local row = math.floor((vim.o.lines - h) / 2)
		local col = math.floor((vim.o.columns - w) / 2)
		chat_win = vim.api.nvim_open_win(chat_buf, true, {
			relative = "editor",
			width = w,
			height = h,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
		})
	end

	vim.api.nvim_win_set_buf(chat_win, chat_buf)
	vim.bo[chat_buf].filetype = "markdown"
	vim.bo[chat_buf].buftype = "nofile"
	vim.bo[chat_buf].swapfile = false
	vim.bo[chat_buf].bufhidden = "wipe"
	vim.bo[chat_buf].modifiable = false
	vim.wo[chat_win].wrap = true
	vim.wo[chat_win].linebreak = true

	-- Populate existing messages
	for _, msg in ipairs(messages) do
		if msg.role ~= "system" then
			append_message(msg.role, msg.content)
		end
	end

	-- Close & save on q
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(chat_win, true)
		cm.save(conv_name, messages)
	end, { buffer = chat_buf })

	-- <Enter> to send a prompt
	vim.keymap.set("n", "<CR>", function()
		vim.ui.input({ prompt = "You: " }, function(input)
			if not input then
				return
			end

			-- Append user message
			table.insert(messages, { role = "user", content = input })
			append_message("user", input)
			cm.save(conv_name, messages)

			-- Call OpenAI
			local response = require("code-assist.assistant.chat-completions").create_response(model, messages)
			if response then
				table.insert(messages, { role = "assistant", content = response })
				append_message("assistant", response)
				cm.save(conv_name, messages)
			else
				append_message("assistant", "[Error fetching response]")
			end
		end)
	end, { buffer = chat_buf })
end

return M
