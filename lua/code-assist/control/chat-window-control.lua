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
	ConversationManager.on_conversation_update:subscribe(function(event)
		local filtered = filter_chat_messages(event.messages)
		if event.operation == "append" then
			for _, m in ipairs(filtered) do
				ChatWindow.append_message(m)
			end
		else
			ChatWindow.replace_messages(filtered)
		end
	end)
end

function ChatWindowControl.setup()
	setup_conversation_manager_events()
end

return ChatWindowControl
