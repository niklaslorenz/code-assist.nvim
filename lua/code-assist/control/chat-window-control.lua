local ChatWindowControl = {}

local Keymaps = require("code-assist.control.keymaps")
local ChatWindow = require("code-assist.ui.chat-window")
local ConversationManager = require("code-assist.conversation-manager")

--- Filter out system messages.
--- @param messages Message[]
--- @return Message[] filtered
local function filter_chat_messages(messages)
	local filtered = {}
	for _, m in ipairs(messages) do
		if m.role ~= "system" then
			table.insert(filtered, m)
		end
	end
	return filtered
end

local function setup_conversation_manager_events()
	ConversationManager.on_conversation_switch:subscribe(function(event)
		local messages = event.conversation ~= nil and event.conversation.messages or {}
		local filtered = filter_chat_messages(messages)
		ChatWindow.replace_messages(filtered)
		local title = nil
		if event.conversation.type == "listed" then
			title = "[Conversation] " .. event.conversation.name
		elseif event.conversation.type == "project" then
			title = "[" .. event.conversation.name .. "]"
		end
		ChatWindow.set_title(title)
	end)
	ConversationManager.on_new_message:subscribe(function(event)
		if event.new_message.role ~= "system" then
			ChatWindow.append_message(event.new_message)
		end
	end)
	ConversationManager.on_message_extend:subscribe(function(event)
		ChatWindow.extend_last_message(event.delta)
	end)
end

local function setup_chat_window_events()
	ChatWindow.on_visibility_change:subscribe(function(event)
		if event == "visible" then
			Keymaps.setup_chat_buffer_keymaps(ChatWindow.get_chat_buf())
			if not ConversationManager.has_conversation() then
				ConversationManager.load_last_or_create_new()
			end
		end
	end)
end

function ChatWindowControl.setup()
	setup_conversation_manager_events()
	setup_chat_window_events()
end

return ChatWindowControl
