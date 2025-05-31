local ConversationManagerControl = {}

local ConversationManager = require("code-assist.conversations.manager")
local Windows = require("code-assist.ui.window-instances")

--- @param item ConversationItem
local function parse_item(item)
	local header = "*" .. item:get_user_descriptor() .. ":*"

	local item_lines = { "___", header }
	local content = item:print() or "<empty>"
	for _, line in ipairs(vim.split(content, "\n")) do
		table.insert(item_lines, line)
	end
	local item_content = table.concat(item_lines, "\n")
	--- @type ContentWindowItem
	local window_item = {
		content = item_content,
		channel = item.channel,
	}
	return window_item
end

function ConversationManagerControl.setup()
	ConversationManager.observer.on_conversation_switch:subscribe(function(event)
		local items = event.new_conversation ~= nil and event.new_conversation:get_content() or {}
		Windows.Chat:clear()
		for _, m in ipairs(items) do
			Windows.Chat:add_item(parse_item(m))
		end
		local title = nil
		if event.new_conversation then
			local type = event.new_conversation:get_type()
			if type == "listed" then
				title = "[Conversation] " .. event.new_conversation.name
			elseif type == "project" then
				title = "[" .. event.new_conversation.name .. "]"
			end
		end
		Windows.Chat:set_title(title)
	end)

	ConversationManager.observer.on_new_item:subscribe(function(event)
		Windows.Chat:add_item(parse_item(event.item))
	end)

	ConversationManager.observer.on_item_extended:subscribe(function(event)
		Windows.Chat:append_to_last_item(event.extension)
	end)

	ConversationManager.observer.on_item_deleted:subscribe(function(_)
		Windows.Chat:remove_last_item()
	end)
end

return ConversationManagerControl
