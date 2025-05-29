local ChatInputWindowControl = {}

local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversations.manager")
local Keymaps = require("code-assist.control.keymaps")

function ChatInputWindowControl.setup()
	-- Turn on line wrap and setup keymaps
	Windows.ChatInput.on_visibility_change:subscribe(function(event)
		if event == "visible" or event == "layout" then
			local win = Windows.ChatInput:get_win()
			assert(win)
			-- Turn on line wrap
			vim.wo[win].wrap = true
		end
		if event == "visible" then
			local buf = Windows.ChatInput:get_buf()
			assert(buf)
			-- Setup keymaps
			Keymaps.setup_chat_input_buffer_keymaps(buf)
		end
	end)

	Windows.ChatInput.on_submit:subscribe(function(event)
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
			return
		end
		local conv = ConversationManager.get_conversation()
		if not conv then
			vim.notify("No current conversation", vim.log.levels.INFO)
			return
		end
		if not conv:can_handle_text() then
			vim.notify("This conversation does not support text input.")
			return
		end
		conv:handle_user_input_text(event)
		conv:prompt_response()
		Windows.ChatInput:clear()
	end)
end

return ChatInputWindowControl
