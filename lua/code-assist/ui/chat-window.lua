local ChatWindow = {}

--- @alias WindowOrientation "hsplit"|"vsplit"|"float"

--- @alias WindowDisplayEvent "show"|"hide"

--- @alias ChatKeymapFunction fun(win: integer, buf: integer)

local EventDispatcher = require("code-assist.event-dispatcher")
local ConversationManager = require("code-assist.conversation-manager")

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

--- Highlighting namespace
local ns = vim.api.nvim_create_namespace("code-assist")

--- Get the chat window if it is valid.
--- @return integer|nil window
local function get_win()
	if chat_win and vim.api.nvim_win_is_valid(chat_win) then
		return chat_win
	end
	return nil
end

--- Print a message to the buffer
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

--- Create a new keymap for the chat window.
--- @param key string
--- @param func fun()
local function add_keymap(key, func)
	vim.keymap.set("n", key, function()
		func()
	end, { buffer = chat_buf })
end

local function setup_keymaps()
	add_keymap("q", function()
		ChatWindow.hide()
	end)
	add_keymap("<CR>", function()
		vim.ui.input({ prompt = "You: " }, function(input)
			if not input then
				return
			end
			local success, reason = ConversationManager.append_message({ role = "user", content = input })
			if success then
				ConversationManager.generate_response()
			elseif reason then
				vim.notify(reason, vim.log.levels.ERROR)
			end
		end)
	end)
	add_keymap("r", function()
		local name = ConversationManager.get_current_conversation().name
		vim.ui.input({ prompt = "Rename:", default = name }, function(input)
			if not input then
				return
			end
			ConversationManager.rename_conversation(name, input)
		end)
	end)
	add_keymap("d", function()
		local name = ConversationManager.get_current_conversation().name
		vim.ui.input({ prompt = "Delete?" }, function(input)
			if not input or input ~= "yes" then
				return
			end
			ConversationManager.delete_conversation(name)
			-- TODO: What to do after deleting the current conversation?
		end)
	end)
	add_keymap("n", function()
		vim.ui.input({ prompt = "New:" }, function(input)
			if not input then
				return
			end
			ConversationManager.new_conversation(input)
		end)
	end)
end

--- Append a message to the chat window.
--- @param message Message
function ChatWindow.append_message(message)
	table.insert(messages, message)
	vim.bo[chat_buf].modifiable = true
	print_message(message)
	vim.bo[chat_buf].modifiable = false
	ChatWindow.scroll_to_bottom()
end

--- Scroll the chat window to the bottom.
function ChatWindow.scroll_to_bottom()
	local win = get_win()
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
	local win = get_win()
	if not win then
		return
	end
	vim.api.nvim_win_close(win, true)
	ChatWindow.on_visibility_change:dispatch("hide")
end

--- Show the chat window.
--- @param orientation WindowOrientation
function ChatWindow.open(orientation)
	-- If already open, jump there
	local win = get_win()
	if win then
		vim.api.nvim_set_current_win(win)
		return
	end
	-- Create the window
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
		win = vim.api.nvim_open_win(temp_buf, true, {
			relative = "editor",
			width = w,
			height = h,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
		})
	end
	chat_win = win
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.api.nvim_win_set_buf(win, chat_buf)
	setup_keymaps()
	ChatWindow.on_visibility_change:dispatch("show")
end

--- @type EventDispatcher<WindowDisplayEvent>
ChatWindow.on_visibility_change = EventDispatcher.new()

return ChatWindow
