local ChatCommand = {}

local SelectWindow = require("code-assist.ui.select-window")
local ConversationManager = require("code-assist.conversation-manager")
local ChatWindow = require("code-assist.ui.chat-window")

ChatCommand.create_new_conversation = function()
	vim.ui.input({ prompt = "New Chat:" }, function(input)
		if not input then
			return
		end
		if input == "" then
			input = nil
		end
		ConversationManager.new_conversation(input)
		ChatWindow.open()
	end)
end

ChatCommand.select_conversation = function()
	SelectWindow.open()
end

ChatCommand.open_vertical_split = function()
	ChatWindow.open("vsplit")
end

ChatCommand.open_horizontal_split = function()
	ChatWindow.open("hsplit")
end

ChatCommand.open_float = function()
	ChatWindow.open("float")
end

ChatCommand.open = function()
	ChatWindow.open()
end

ChatCommand.prompt_message = function()
	vim.ui.input({ prompt = "You: " }, function(input)
		if not input then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager not ready.")
			return
		end
		local success, reason = ConversationManager.add_message({ role = "user", content = input })
		if success then
			ConversationManager.generate_streaming_response()
		elseif reason then
			vim.notify(reason, vim.log.levels.ERROR)
		end
	end)
end

ChatCommand.copy_selection = function()
	-- TODO: implement
	vim.notify("Not implemented yet.", vim.log.levels.WARN)
end

ChatCommand.prompt_selection_message = function()
	-- TODO: implement
	vim.notify("Not implemented yes.", vim.log.levels.WARN)
end

ChatCommand.scroll_to_bottom = function()
	ChatWindow.scroll_to_bottom()
end

ChatCommand.run = function(opts)
	-- parse args
	local args = {}
	for arg in string.gmatch(opts.args or "", "%S+") do
		table.insert(args, arg)
	end
	local mode, layout = args[1], args[2]
	-- if only one arg, treat it as layout
	if layout == nil then
		layout = mode
		mode = nil
	end
	-- determine flags
	local is_new = (mode == "n" or mode == "new")
	local is_select = (mode == "s" or mode == "select")
	-- determine orientation
	--- @type WindowOrientation
	local orientation = "float"
	if layout == "h" or layout == "horizontal" then
		orientation = "hsplit"
	elseif layout == "v" or layout == "vertical" then
		orientation = "vsplit"
	end

	if is_select then
		SelectWindow.set_chat_orientation(orientation)
		SelectWindow.open()
	elseif is_new then
		vim.ui.input({ prompt = "New Chat:" }, function(input)
			if not input then
				return
			end
			if input == "" then
				input = nil
			end
			ConversationManager.new_conversation(input)
			ChatWindow.open(orientation)
		end)
	else
		ConversationManager.load_last_or_create_new()
		ChatWindow.open(orientation)
	end
end

ChatCommand.setup = function()
	vim.api.nvim_create_user_command("Chat", ChatCommand.run, {
		nargs = "*",
		complete = function(ArgLead)
			local opts = { "f", "h", "v", "n f", "n h", "n v", "s f", "s h", "s v" }
			return vim.tbl_filter(function(val)
				return vim.startswith(val, ArgLead)
			end, opts)
		end,
	})
end

return ChatCommand
