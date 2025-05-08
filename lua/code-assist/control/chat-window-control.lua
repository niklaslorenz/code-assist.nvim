local ChatWindowControl = {}

local Options = require("code-assist.options")
local Keymaps = require("code-assist.control.keymaps")
local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversation-manager")

function ChatWindowControl.setup()
	Windows.Chat.on_visibility_change:subscribe(function(event)
		if event == "visible" or event == "layout" then
			local win = Windows.Chat:get_win()
			assert(win)
			-- Turn on line wrap
			vim.wo[win].wrap = true

			-- Adjust input window
			local orientation = Windows.Chat:get_orientation()
			if orientation == "hsplit" then
				Windows.ChatInput:show({
					orientation = "vsplit",
					origin = Windows.Chat,
					relative_width = Options.relative_chat_input_width,
				})
			elseif orientation == "vsplit" then
				Windows.ChatInput:show({
					orientation = "hsplit",
					origin = Windows.Chat,
					relative_height = Options.relative_chat_input_height,
				})
			else
				Windows.ChatInput:hide()
			end
		else
			Windows.ChatInput:hide()
		end

		if event == "visible" then
			local buf = Windows.Chat:get_buf()
			assert(buf)
			-- Load conversation
			if not ConversationManager.has_conversation() then
				ConversationManager.load_last_or_create_new()
			end
			-- Setup keymaps
			Keymaps.setup_chat_buffer_keymaps(buf)
		end
	end)
end

return ChatWindowControl
