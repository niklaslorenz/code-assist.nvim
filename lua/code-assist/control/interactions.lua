local Interactions = {}

local Util = require("code-assist.util")
local OptionsWindow = require("code-assist.ui.options-window")
local Options = require("code-assist.options")
local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversations.manager")
local ConversationSelectWindow = require("code-assist.ui.conversation-select-window")
local ConversationIO = require("code-assist.conversations.io")

local function get_current_filetype()
	return vim.bo.filetype
end

function Interactions.open_floating_window()
	Windows.Chat:show({
		orientation = "float",
	})
end

function Interactions.open_vertical_split()
	Windows.Chat:show({
		orientation = "vsplit",
		relative_width = Options.relative_chat_width,
	})
end

function Interactions.open_horizontal_split()
	Windows.Chat:show({
		orientation = "hsplit",
		relative_height = Options.relative_chat_height,
	})
end

function Interactions.open()
	Windows.Chat:show({
		relative_height = Options.relative_chat_height,
		relative_width = Options.relative_chat_width,
	})
end

function Interactions.open_listed_conversations_selection()
	local window = ConversationSelectWindow:new("float", nil, Options.default_sort_order, "listed")
	window.on_select:subscribe(function(event)
		local conversation = ConversationIO.load_listed_conversation(event)
		if not conversation then
			vim.notify("Could not load conversation: " .. event)
			return
		end
		ConversationManager.set_conversation(conversation)
		Windows.Chat:show()
		window:dispose()
	end)
	window:set_title("Listed Conversations")
	window:show()
end

function Interactions.open_project_conversations_selection()
	local window = ConversationSelectWindow:new("float", nil, Options.default_sort_order, "project")
	window.on_select:subscribe(function(event)
		local conversation = ConversationIO.load_project_conversation(event)
		ConversationManager.set_conversation(conversation)
		Windows.Chat:show()
		window:dispose()
	end)
	window:set_title("Project Conversations")
	window:show()
end

function Interactions.goto_message_input()
	if Windows.Chat:get_orientation() == "float" or not Windows.ChatInput:is_visible() then
		Interactions.open_message_prompt()
	else
		local win = Windows.ChatInput:get_win()
		local buf = Windows.ChatInput:get_buf()
		assert(win)
		assert(buf)
		vim.api.nvim_set_current_win(win)
		local last_line = vim.api.nvim_buf_line_count(buf)
		local last_col = #vim.api.nvim_buf_get_lines(buf, last_line - 1, last_line, true)[1]
		vim.api.nvim_win_set_cursor(win, { last_line, last_col })
		vim.api.nvim_feedkeys("a", "n", false)
	end
end

function Interactions.open_message_prompt()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready")
		return
	end
	local conv = ConversationManager.get_conversation()
	if not conv then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	if not conv:can_handle_text() then
		vim.notify("This conversation does not support text input", vim.log.levels.INFO)
		return
	end
	vim.ui.input({ prompt = "You: " }, function(input)
		if not input then
			return
		end
		vim.notify("Handling user input in interactions: " .. input, vim.log.levels.TRACE) -- WARN: trace
		conv:handle_user_input_text(input)
		conv:prompt_response()
	end)
end

function Interactions.open_message_prompt_for_selection()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	local selection = Util.get_current_selection()
	local filetype = get_current_filetype()
	local content = "```" .. filetype .. "\n" .. selection .. "\n```"
	vim.ui.input({ prompt = "You: " }, function(input)
		if not input then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager not ready")
			return
		end
		local conv = ConversationManager.get_conversation()
		if not conv then
			vim.notify("No current conversation")
			return
		end
		conv:handle_text_context(content)
		conv:handle_user_input_text(input)
		conv:prompt_response()
	end)
end

function Interactions.copy_selection()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
		return
	end
	local conv = ConversationManager.get_conversation()
	if not conv then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	if not conv:can_handle_text() then
		vim.notify("This conversation does not support text input")
		return
	end
	local selection = Util.get_current_selection()
	local filetype = get_current_filetype()
	local content = "```" .. filetype .. "\n" .. selection .. "\n```"
	conv:handle_text_context(content)
	Windows.Chat:scroll_to_bottom()
	if conv:get_type() ~= "unlisted" then
		local ok, reason = ConversationIO.save_conversation(conv)
		if not ok then
			vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
		end
	end
end

function Interactions.close_chat_window()
	Windows.Chat:hide()
end

function Interactions.create_new_unlisted_conversation()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready")
		return
	end
	local conv = Util.get_default_conversation_class():create_unlisted()
	ConversationManager.set_conversation(conv)
	Windows.Chat:show()
end

function Interactions.create_new_project_conversation()
	vim.ui.input({ prompt = "New Project Conversation: " }, function(input)
		if not input then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("ConversationManager is not ready")
			return
		end
		if input == "" then
			input = nil
		end
		local path = Util.get_current_neo_tree_path()
		if not path then
			vim.notify("Could not find project path", vim.log.levels.INFO)
			return
		end
		local conv = Util.get_default_conversation_class():create_project(input, path)
		ConversationManager.set_conversation(conv)
		Windows.Chat:show()
	end)
end

function Interactions.create_new_listed_conversation()
	vim.ui.input({ prompt = "New Conversation:" }, function(input)
		if not input then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager is not ready")
			return
		end
		if input == "" then
			input = nil
		end
		local conv = Util.get_default_conversation_class():create_listed(input)
		ConversationManager.set_conversation(conv)
		Windows.Chat:show()
	end)
end

function Interactions.rename_current_conversation()
	local conversation = ConversationManager.get_conversation()
	if not conversation then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready", vim.log.levels.INFO)
		return
	end
	vim.ui.input({ prompt = "Rename:", default = conversation.name }, function(input)
		if not input then
			return
		end
		local ok, msg = ConversationIO.rename_conversation(conversation, input)
		if not ok then
			vim.notify(msg or "Unknown error", vim.log.levels.ERROR)
		end
	end)
end

function Interactions.delete_current_conversation()
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation")
		return
	end
	local conversation = ConversationManager.get_conversation()
	assert(conversation)
	vim.ui.input({ prompt = "Delete?" }, function(input)
		if not input or input ~= "yes" and input ~= "y" then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager is not ready", vim.log.levels.INFO)
			return
		end
		local ok, reason = ConversationIO.delete_conversation(conversation)
		if not ok then
			vim.notify(reason or "Unknown error", vim.log.levels.INFO)
		end
	end)
end

function Interactions.delete_last_message()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready", vim.log.levels.INFO)
		return
	end
	local conv = ConversationManager.get_conversation()
	if not conv then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	local removed = conv:remove_last_item()
	if not removed then
		vim.notify("Could not remove the last conversation item", vim.log.levels.INFO)
	end
end

function Interactions.generate_response()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready")
		return
	end
	local conv = ConversationManager.get_conversation()
	if not conv then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	conv:prompt_response()
end

function Interactions.scroll_to_bottom()
	Windows.Chat:scroll_to_bottom()
end

function Interactions.scroll_to_next_begin()
	Windows.Chat:scroll_to_next_item(true)
end

function Interactions.scroll_to_previous_begin()
	Windows.Chat:scroll_to_previous_item(true)
end

function Interactions.open_chat_filter_window()
	local win = OptionsWindow:new(Windows.Chat:get_filters(), "*Chat Channels:*", "float")
	win.on_submit:subscribe(function(event)
		for k, v in pairs(event) do
			print("New filter" .. k .. ": " .. (v and "true" or "false"))
			Windows.Chat:set_filter(k, v)
			Windows.Chat:refresh_content()
		end
	end)
	win:show()
end

return Interactions
