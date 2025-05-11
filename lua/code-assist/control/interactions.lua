local Interactions = {}

local OptionsWindow = require("code-assist.ui.options-window")
local Options = require("code-assist.options")
local Windows = require("code-assist.ui.window-instances")
local ConversationManager = require("code-assist.conversation-manager")
local ConversationSelectWindow = require("code-assist.ui.conversation-select-window")

local function get_current_selection()
	local mode = vim.fn.mode()
	local start_pos, end_pos

	if mode == "v" or mode == "V" then
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")
	else
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
	end

	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local start_col = start_pos[3]
	local end_col = end_pos[3]

	if start_line > end_line then
		local x = start_line
		start_line = end_line
		end_line = x
		x = start_col
		start_col = end_col
		end_col = x
	end

	local selected_lines = {}

	if mode == "v" then
		-- Character-wise selection
		for line_num = start_line, end_line do
			local line = vim.fn.getline(line_num)
			if line_num == start_line and line_num == end_line then
				table.insert(selected_lines, line:sub(start_col, end_col))
			elseif line_num == start_line then
				table.insert(selected_lines, line:sub(start_col))
			elseif line_num == end_line then
				table.insert(selected_lines, line:sub(1, end_col))
			else
				table.insert(selected_lines, line)
			end
		end
	elseif mode == "V" then
		-- Line-wise selection
		for line_num = start_line, end_line do
			table.insert(selected_lines, vim.fn.getline(line_num))
		end
	end
	local selection = table.concat(selected_lines, "\n")
	return selection
end

-- local function get_current_selection()
-- 	local mode = vim.fn.mode()
-- 	local start_pos, end_pos
-- 	if mode == "v" or mode == "V" or mode == "\22" then
-- 		start_pos = vim.fn.getpos("v")
-- 		end_pos = vim.fn.getpos(".")
-- 	else
-- 		start_pos = vim.fn.getpos("'<")
-- 		end_pos = vim.fn.getpos("'>")
-- 	end
--
-- 	local start_line = start_pos[2]
-- 	local end_line = end_pos[2]
--
-- 	local selected_lines = {}
--
-- 	for line_num = start_line, end_line do
-- 		local line = vim.fn.getline(line_num)
-- 		if line_num == start_line and line_num == end_line then
-- 			local start_col = start_pos[3]
-- 			local end_col = end_pos[3]
-- 			table.insert(selected_lines, line:sub(start_col, end_col))
-- 		elseif line_num == start_line then
-- 			local start_col = start_pos[3]
-- 			table.insert(selected_lines, line:sub(start_col))
-- 		elseif line_num == end_line then
-- 			local end_col = end_pos[3]
-- 			table.insert(selected_lines, line:sub(1, end_col))
-- 		else
-- 			table.insert(selected_lines, line)
-- 		end
-- 	end
-- 	local selection = table.concat(selected_lines, "\n")
-- 	return selection
-- end

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
	local window = ConversationSelectWindow:new("float", nil, nil, Options.default_sort_order)
	window.on_select:subscribe(function(event)
		local ok, reason = ConversationManager.load_conversation(event)
		if not ok then
			vim.notify(reason or "Unknown error", vim.log.levels.INFO)
		end
		Windows.Chat:show()
		window:dispose()
	end)
	window:set_title("Listed Conversations")
	window:show()
end

function Interactions.open_project_conversations_selection()
	-- TODO: implement (where to get path?)
	local path = "?"
	local window = ConversationSelectWindow:new("float", nil, path, Options.default_sort_order)
	window.on_select:subscribe(function(event)
		local ok, reason = ConversationManager.load_conversation(event)
		if not ok then
			vim.notify(reason or "Unknown error", vim.log.levels.INFO)
		end
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
	if not ConversationManager.has_conversation() then
		ConversationManager.new_unlisted_conversation()
	end
	vim.ui.input({ prompt = "You: " }, function(input)
		if not input then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager not ready")
			return
		end
		if not ConversationManager.has_conversation() then
			vim.notify("No current conversation")
			return
		end
		ConversationManager.add_message({ role = "user", content = input })
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

function Interactions.open_message_prompt_for_selection()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	local selection = get_current_selection()
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
		if not ConversationManager.has_conversation() then
			vim.notify("No current conversation")
			return
		end
		ConversationManager.add_message({ role = "user", content = content })
		ConversationManager.add_message({ role = "user", content = input })
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

function Interactions.copy_selection()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready", vim.log.levels.INFO)
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	local selection = get_current_selection()
	local filetype = get_current_filetype()
	local content = "```" .. filetype .. "\n" .. selection .. "\n```"
	ConversationManager.add_message({
		role = "user",
		content = content,
	})
	Windows.Chat:scroll_to_bottom()
	if ConversationManager.get_current_conversation().type ~= "unlisted" then
		local ok, reason = ConversationManager.save_current_conversation()
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
	ConversationManager.new_unlisted_conversation()
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
		local created = ConversationManager.new_project_conversation(input)
		if created then
			Windows.Chat:show()
		end
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
		ConversationManager.new_listed_conversation(input)
		Windows.Chat:show()
	end)
end

function Interactions.rename_current_conversation()
	local conversation = ConversationManager.get_current_conversation()
	if not conversation then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready", vim.log.levels.INFO)
		return
	end
	local switch = {
		["listed"] = function()
			vim.ui.input({ prompt = "Rename:", default = conversation.name }, function(input)
				if not input then
					return
				end
				local ok, msg = ConversationManager.rename_conversation(conversation.name, input)
				if not ok then
					vim.notify(msg or "Unknown error", vim.log.levels.ERROR)
				end
			end)
		end,
		["unlisted"] = function()
			vim.ui.input({ prompt = "Name:" }, function(input)
				if not input then
					return
				end
				local ok, msg = ConversationManager.convert_current_conversation_to_listed(input)
				if not ok then
					vim.notify(msg or "Unknown error", vim.log.levels.ERROR)
				end
			end)
		end,
		["project"] = function()
			-- TODO: implement
			error("Saving project conversations is not supported yet")
		end,
	}
	local switch_default = function()
		error("Invalid conversation type: " .. conversation.type)
	end;
	(switch[conversation.type] or switch_default)()
end

function Interactions.delete_current_conversation()
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation")
		return
	end
	local name = ConversationManager.get_current_conversation().name
	vim.ui.input({ prompt = "Delete?" }, function(input)
		if not input or input ~= "yes" and input ~= "y" then
			return
		end
		if not ConversationManager.is_ready() then
			vim.notify("Conversation Manager is not ready", vim.log.levels.INFO)
			return
		end
		local ok, reason = ConversationManager.delete_conversation(name)
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
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	ConversationManager.delete_last_message()
	if ConversationManager.get_current_conversation().type ~= "unlisted" then
		local ok, reason = ConversationManager.save_current_conversation()
		if not ok then
			vim.notify(reason or "Unknown error", vim.log.levels.INFO)
		end
	end
end

function Interactions.generate_response()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready")
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.levels.INFO)
		return
	end
	ConversationManager.generate_streaming_response()
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
