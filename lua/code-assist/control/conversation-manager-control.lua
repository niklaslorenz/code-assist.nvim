local ConversationManagerControl = {}

local ConversationManager = require("code-assist.conversation-manager")
local Windows = require("code-assist.ui.window-instances")

--- @param item Message
local function parse_item(item)
	local header
	if item.role == "user" then
		header = "*User:*"
	elseif item.role == "assistant" then
		header = "*Assistant:*"
	else
		header = "*System:*"
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

function ConversationManagerControl.setup()
	ConversationManager.on_conversation_switch:subscribe(function(event)
		local messages = event.conversation ~= nil and event.conversation.messages or {}
		Windows.Chat:clear()
		for _, m in ipairs(messages) do
			Windows.Chat:add_item(parse_item(m))
		end
		local title = nil
		if event.conversation then
			if event.conversation.type == "listed" then
				title = "[Conversation] " .. event.conversation.name
			elseif event.conversation.type == "project" then
				title = "[" .. event.conversation.name .. "]"
			end
		end
		Windows.Chat:set_title(title)
	end)

	ConversationManager.on_new_message:subscribe(function(event)
		if event.new_message.role ~= "system" then
			Windows.Chat:add_item(parse_item(event.new_message))
		end
	end)

	ConversationManager.on_message_extend:subscribe(function(event)
		Windows.Chat:append_to_last_item(event.delta)
	end)
end

return ConversationManagerControl
