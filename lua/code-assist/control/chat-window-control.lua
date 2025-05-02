local ChatWindowControl = {}

local Keymaps = require("code-assist.control.keymaps")
local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversation-manager")

local ChatWindow = Windows.Chat

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

--- @param item Message
local function parse_item(item)
	local header
	if item.role == "user" then
		header = "*User:*"
	else
		header = "*Assistant:*"
	end

	local item_lines = { "___", header }
	for _, line in ipairs(vim.split(item.content, "\n")) do
		table.insert(item_lines, line)
	end
	local item_content = table.concat(item_lines, "\n")
	--- @type ContentWindowItem
	local window_item = {
		content = item_content,
		channel = item.role,
	}
	return window_item
end

local function setup_conversation_manager_events()
	ConversationManager.on_conversation_switch:subscribe(function(event)
		local messages = event.conversation ~= nil and event.conversation.messages or {}
		local filtered = filter_chat_messages(messages)
		ChatWindow:clear()
		for _, m in ipairs(filtered) do
			ChatWindow:add_item(parse_item(m))
		end
		local title = nil
		if event.conversation.type == "listed" then
			title = "[Conversation] " .. event.conversation.name
		elseif event.conversation.type == "project" then
			title = "[" .. event.conversation.name .. "]"
		end
		ChatWindow:set_title(title)
	end)

	ConversationManager.on_new_message:subscribe(function(event)
		if event.new_message.role ~= "system" then
			ChatWindow:add_item(parse_item(event.new_message))
		end
	end)

	ConversationManager.on_message_extend:subscribe(function(event)
		ChatWindow:append_to_last_item(event.delta)
	end)
end

local function setup_chat_window_events()
	ChatWindow.on_status_change:subscribe(function(event)
		if event == "visible" then
			Keymaps.setup_chat_buffer_keymaps(ChatWindow:get_buf())
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
