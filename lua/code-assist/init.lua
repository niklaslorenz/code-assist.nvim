local M = {}

local has_plenary = pcall(require, "plenary")
if not has_plenary then
	error("plenary.nvim is required but not installed")
	return
end

local PluginOptions = require("code-assist.options")
local ConversationManager = require("code-assist.conversation-manager")
local ChatWindowControl = require("code-assist.control.chat-window-control")
local ChatWindow = require("code-assist.ui.chat-window")
local Keymaps = require("code-assist.control.keymaps")

function M.setup(opts)
	if opts then
		for k, v in pairs(opts) do
			if PluginOptions[k] then
				PluginOptions[k] = v
			end
		end
	end

	vim.api.nvim_set_hl(0, "ChatUser", { fg = PluginOptions.user_chat_color, bold = true })
	vim.api.nvim_set_hl(0, "ChatAssistant", { fg = PluginOptions.assistant_chat_color, bold = true })

	ConversationManager.setup()
	ChatWindowControl.setup()
	Keymaps.setup_global_keymaps()

	ChatWindow.on_visibility_change:subscribe(function(event)
		if event == "visible" then
			Keymaps.setup_chat_buffer_keymaps(ChatWindow.get_chat_buf())
			if not ConversationManager.has_conversation() then
				ConversationManager.load_last_or_create_new()
			end
		end
	end)
end

return M
