local ChatCommand = {}

local SelectWindow = require("code-assist.ui.select-window")
local ConversationManager = require("code-assist.conversation-manager")
local ChatWindow = require("code-assist.ui.chat-window")

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
		ConversationManager.new_conversation()
		ChatWindow.open(orientation)
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
