local ChatWindowControl = {}

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
		local messages = event.conversation and event.conversation.messages or {}
		local filtered = filter_chat_messages(messages)
		ChatWindow.replace_messages(filtered)
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

function ChatWindowControl.setup()
	setup_conversation_manager_events()
end

return ChatWindowControl
