local ConversationManagerControl = {}

local ConversationManager = require("code-assist.conversations.manager")
local Windows = require("code-assist.ui.window-instances")

--- @param item ConversationItem
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
	local content = item:print() or "<empty>"
	for _, line in ipairs(vim.split(content, "\n")) do
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
		local items = event.conversation ~= nil and event.conversation.content or {}
		Windows.Chat:clear()
		for _, m in ipairs(items) do
			Windows.Chat:add_item(parse_item(m))
		end
		local title = nil
		if event.conversation then
			local type
			event.conversation:get_type()
			if type == "listed" then
				title = "[Conversation] " .. event.conversation.name
			elseif type == "project" then
				title = "[" .. event.conversation.name .. "]"
			end
		end
		Windows.Chat:set_title(title)
	end)

	ConversationManager.on_new_item:subscribe(function(event)
		Windows.Chat:add_item(parse_item(event.new_item))
	end)

	ConversationManager.on_message_extended:subscribe(function(event)
		Windows.Chat:append_to_last_item(event.delta)
	end)
end

return ConversationManagerControl
