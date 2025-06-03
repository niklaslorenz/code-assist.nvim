local ConversationManagerControl = {}

local ConversationManager = require("code-assist.conversations.manager")
local Windows = require("code-assist.ui.window-instances")

--- @param item ConversationItem
local function parse_item(item)
	local header = "*" .. item:get_channel_descriptor() .. ":*"

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

local function reload_window_content(conv)
	local items = conv ~= nil and conv:get_content() or {}
	Windows.Chat:clear()
	for _, m in ipairs(items) do
		Windows.Chat:add_item(parse_item(m))
	end
	local title = nil
	if conv then
		local type = conv:get_type()
		if type == "listed" then
			title = "[Conversation] " .. conv.name
		elseif type == "project" then
			title = "[" .. conv.name .. "]"
		end
	end
	Windows.Chat:set_title(title)
end

function ConversationManagerControl.setup()
	ConversationManager.observer.on_conversation_switch:subscribe(function(event)
		reload_window_content(event.new_conversation)
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

	ConversationManager.observer.on_conversation_update:subscribe(function(event)
		reload_window_content(event.conversation)
	end)
end

return ConversationManagerControl
