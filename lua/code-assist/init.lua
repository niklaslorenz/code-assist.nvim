-- Expose user commands and keymaps
local ConversationManager = require("code-assist.conversation-manager")
local ChatWindowControl = require("code-assist.control.chat-window-control")
local ChatCommand = require("code-assist.commands.chat")
local ChatWindow = require("code-assist.ui.chat-window")

--- @param mode string|string[]
--- @param key string
--- @param callback fun()
local function add_keymap(mode, key, callback)
	vim.keymap.set(mode, key, callback, { noremap = true, silent = true })
end

local function define_global_keymaps()
	add_keymap("n", "<leader>an", ChatCommand.create_new_conversation)
	add_keymap("n", "<leader>as", ChatCommand.select_conversation)
	add_keymap("n", "<leader>av", ChatCommand.open_vertical_split)
	add_keymap("n", "<leader>ah", ChatCommand.open_horizontal_split)
	add_keymap("n", "<leader>af", ChatCommand.open_float)
	add_keymap("n", "<leader>ao", ChatCommand.open)
	add_keymap("n", "<leader>am", ChatCommand.prompt_message)
	add_keymap("v", "<leader>ac", ChatCommand.copy_selection)
	add_keymap("v", "<leader>am", ChatCommand.prompt_selection_message)
	add_keymap({ "n", "v" }, "<leader>ab", ChatCommand.scroll_to_bottom)
end

local function setup()
	vim.api.nvim_set_hl(0, "ChatUser", { fg = "#a3be8c", bold = true })
	vim.api.nvim_set_hl(0, "ChatAssistant", { fg = "#88c0d0", bold = true })

	ConversationManager.setup()
	ChatWindowControl.setup()
	ChatCommand.setup()
	define_global_keymaps()

	ChatWindow.on_visibility_change:subscribe(function(event)
		if event == "show" then
			if not ConversationManager.has_conversation() then
				ConversationManager.load_last_or_create_new()
			end
		end
	end)
end

setup()
