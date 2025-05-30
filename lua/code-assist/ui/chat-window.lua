local ChatWindow = {}

local EventDispatcher = require("code-assist.event-dispatcher")

--- Setup the chat buffer or setup a new one if one exists already.
--- @return integer buffer
local function create_buffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	return buf
end

--- The nvim chat buffer
--- @type integer
local chat_buf = create_buffer()

--- The nvim chat window
--- @type integer | nil
local chat_win = nil

--- The messages displayed in the window
--- @type Message[]
local messages = {}

--- @type string?
local title = nil

--- @type WindowOrientation
local last_orientation = "float"

--- Highlighting namespace
local ns = vim.api.nvim_create_namespace("code-assist")

--- Determine whether auto scrolling is currently on.
--- @nodiscard
--- @return boolean auto_scroll
local function auto_scroll()
	local win = ChatWindow.get_win()
	if not win then
		return false
	end
	local pos = vim.api.nvim_win_get_cursor(win)
	if pos[1] >= vim.api.nvim_buf_line_count(chat_buf) then
		return true
	end
	return false
end

--- Print a message to the buffer.
--- @param message Message
local function print_message(message)
	local header = (message.role == "user" and "You:" or "Assistant:")
	local line_count = vim.api.nvim_buf_line_count(chat_buf)
	vim.api.nvim_buf_set_lines(chat_buf, line_count, line_count, false, { header })
	local h1_group = (message.role == "user" and "ChatUser" or "ChatAssistant")
	vim.api.nvim_buf_add_highlight(chat_buf, ns, h1_group, line_count, 0, -1)
	local body_lines = {}
	for _, ln in ipairs(vim.split(message.content, "\n")) do
		table.insert(body_lines, "  " .. ln)
	end
	vim.api.nvim_buf_set_lines(chat_buf, line_count + 1, line_count + 1, false, body_lines)
end

--- Print the extension of the last message to the buffer.
--- @param delta string
local function print_message_extension(delta)
	local followup_lines = {}
	local base_line
	for i, ln in ipairs(vim.split(delta, "\n")) do
		if i ~= 1 then
			table.insert(followup_lines, " " .. ln)
		else
			base_line = ln
		end
	end
	local line_count = vim.api.nvim_buf_line_count(chat_buf)
	local last_line = vim.api.nvim_buf_get_lines(chat_buf, line_count - 1, line_count, true)[1]
	vim.api.nvim_buf_set_lines(chat_buf, line_count - 1, line_count, true, { last_line .. base_line })
	if #followup_lines ~= 0 then
		vim.api.nvim_buf_set_lines(chat_buf, line_count, line_count + 1, false, followup_lines)
	end
end

--- Clear the chat display (not the messages held by the window).
local function clear_buffer()
	vim.bo[chat_buf].modifiable = true
	local line_count = vim.api.nvim_buf_line_count(chat_buf)
	vim.api.nvim_buf_set_lines(chat_buf, 0, line_count, true, {})
	vim.bo[chat_buf].modifiable = false
	ChatWindow.scroll_to_bottom()
end

--- Redraw the chat window.
local function redraw()
	clear_buffer()
	vim.bo[chat_buf].modifiable = true
	for _, m in ipairs(messages) do
		print_message(m)
	end
	vim.bo[chat_buf].modifiable = false
end

--- Get the chat window if it is valid.
--- @return integer|nil window
function ChatWindow.get_win()
	if chat_win and vim.api.nvim_win_is_valid(chat_win) then
		return chat_win
	end
	return nil
end

--- Get the chat buffer.
--- @return integer
function ChatWindow.get_chat_buf()
	return chat_buf
end

--- @param new_title string?
function ChatWindow.set_title(new_title)
	title = new_title
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	local win_config = vim.api.nvim_win_get_config(win)
	if not win_config.relative or win_config.relative == "" then
		return
	end
	win_config.title = title
	if not title then
		win_config.title_pos = nil
	else
		win_config.title_pos = "center"
	end
	print("Relative: " .. win_config.relative)
	vim.api.nvim_win_set_config(win, win_config)
end

--- Append a message to the chat window.
--- @param message Message
function ChatWindow.append_message(message)
	table.insert(messages, message)
	local scroll = auto_scroll()
	vim.bo[chat_buf].modifiable = true
	print_message(message)
	vim.bo[chat_buf].modifiable = false
	if scroll then
		ChatWindow.scroll_to_bottom()
	end
end

--- Extend the last message of the window.
--- @param delta string
function ChatWindow.extend_last_message(delta)
	local last_msg = messages[#messages]
	if not last_msg then
		error("No message to extend.")
	end
	local scroll = auto_scroll()
	vim.bo[chat_buf].modifiable = true
	print_message_extension(delta)
	vim.bo[chat_buf].modifiable = false
	if scroll then
		ChatWindow.scroll_to_bottom()
	end
end

--- Scroll the chat window to the bottom.
function ChatWindow.scroll_to_bottom()
	local win = ChatWindow.get_win()
	if win then
		vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(chat_buf), 0 })
	end
end

--- Replace the current messages in the chat window.
--- @param new_messages Message[]
function ChatWindow.replace_messages(new_messages)
	messages = {}
	for _, m in ipairs(new_messages) do
		table.insert(messages, m)
	end
	redraw()
	ChatWindow.scroll_to_bottom()
end

--- Hide the chat window.
function ChatWindow.hide()
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	vim.api.nvim_win_close(win, true)
	ChatWindow.on_visibility_change:dispatch("hidden")
end

--- Show the chat window.
--- @param orientation WindowOrientation?
function ChatWindow.open(orientation)
	-- If already open, jump there
	local win = ChatWindow.get_win()
	if win then
		if last_orientation == orientation then
			vim.api.nvim_set_current_win(win)
			return
		end
		ChatWindow.hide()
	end
	-- Create the window
	if not orientation then
		orientation = last_orientation
	end
	if orientation == "hsplit" then
		vim.cmd("split")
		win = vim.api.nvim_get_current_win()
	elseif orientation == "vsplit" then
		vim.cmd("vsplit")
		win = vim.api.nvim_get_current_win()
	else
		local w = math.floor(vim.o.columns * 0.6)
		local h = math.floor(vim.o.lines * 0.6)
		local row = math.floor((vim.o.lines - h) / 2)
		local col = math.floor((vim.o.columns - w) / 2)
		local temp_buf = vim.api.nvim_create_buf(false, true)
		local title_pos = nil
		if title ~= nil then
			title_pos = "center"
		end
		win = vim.api.nvim_open_win(temp_buf, true, {
			relative = "editor",
			width = w,
			height = h,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = title,
			title_pos = title_pos,
		})
	end
	last_orientation = orientation
	chat_win = win
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.api.nvim_win_set_buf(win, chat_buf)
	ChatWindow.on_visibility_change:dispatch("visible")
end

function ChatWindow.increase_window_width()
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.width then
		config.width = config.width + 10
	end
	vim.api.nvim_win_set_config(win, config)
end

function ChatWindow.increase_window_height()
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.height then
		config.height = config.height + 5
	end
	vim.api.nvim_win_set_config(win, config)
end

function ChatWindow.decrease_window_width()
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.width then
		config.width = config.width - 10
	end
	vim.api.nvim_win_set_config(win, config)
end

function ChatWindow.decrease_window_height()
	local win = ChatWindow.get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.height then
		config.height = config.height - 5
	end
	vim.api.nvim_win_set_config(win, config)
end

--- @type EventDispatcher<WindowStatus>
ChatWindow.on_visibility_change = EventDispatcher:new()

return ChatWindow
