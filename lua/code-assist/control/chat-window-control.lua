local ChatWindowControl = {}

local Options = require("code-assist.options")
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

local function setup_window_keymaps()
	Keymaps.setup_chat_buffer_keymaps(Windows.Chat:get_buf())
	Keymaps.setup_chat_input_buffer_keymaps(Windows.ChatInput:get_buf())
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
	Windows.Chat.on_visibility_change:subscribe(function(event)
		if event == "visible" then
			local win = Windows.Chat:get_win()
			assert(win)
			vim.wo[win].wrap = true
			if not ConversationManager.has_conversation() then
				ConversationManager.load_last_or_create_new()
			end
		end
	end)

	Windows.Chat.on_visibility_change:subscribe(function(event)
		if event == "visible" then
			local orientation = Windows.Chat:get_orientation()
			if orientation == "hsplit" then
				Windows.ChatInput:show({
					orientation = "vsplit",
					origin = Windows.Chat,
					relative_width = Options.relative_chat_input_width,
				})
			elseif orientation == "vsplit" then
				Windows.ChatInput:show({
					orientation = "hsplit",
					origin = Windows.Chat,
					relative_height = Options.relative_chat_input_height,
				})
			else
				Windows.ChatInput:hide()
			end
		else
			Windows.ChatInput:hide()
		end
	end)

	Windows.ChatInput.on_visibility_change:subscribe(function(event)
		if event == "visible" then
			local win = Windows.ChatInput:get_win()
			assert(win)
			vim.wo[win].wrap = true
		end
	end)

	Windows.ChatInput.on_submit:subscribe(function(event)
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
			return
		end
		if not ConversationManager.has_conversation() then
			vim.notify("No current conversation", vim.log.levels.INFO)
		end
		Windows.ChatInput:clear()
		ConversationManager.add_message({ role = "user", content = event })
		ConversationManager.generate_streaming_response(function(conversation)
			if conversation.type ~= "unlisted" then
				local ok, reason = ConversationManager.save_current_conversation()
				if not ok then
					vim.notify(reason or "Unknown error", vim.log.levels.WARN)
				end
			end
		end)
	end)
end

function ChatWindowControl.setup()
	setup_window_keymaps()
	setup_conversation_manager_events()
	setup_chat_window_events()
end

return ChatWindowControl
