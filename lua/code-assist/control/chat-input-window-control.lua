local ChatInputWindowControl = {}

local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversations.manager")
local ConversationIO = require("code-assist.conversations.io")
local Message = require("code-assist.conversations.message")
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
		if not ConversationManager.has_conversation() then
			vim.notify("No current conversation", vim.log.levels.INFO)
			return
		end
		Windows.ChatInput:clear()
		local message = Message:new("user", "user-direct", event)
		ConversationManager.add_item(message)
		ConversationManager.stream_query(function(conversation)
			if conversation:get_type() ~= "unlisted" then
				local ok, reason = ConversationIO.save_conversation(conversation)
				if not ok then
					vim.notify(reason or "Unknown error", vim.log.levels.WARN)
				end
			end
		end)
	end)
end

return ChatInputWindowControl
