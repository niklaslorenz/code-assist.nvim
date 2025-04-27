local Interactions = {}

local ChatWindow = require("code-assist.ui.chat-window")
local ConversationManager = require("code-assist.conversation-manager")
local SelectWindow = require("code-assist.ui.select-window")

function Interactions.open_floating_window()
	ChatWindow.open("float")
end

function Interactions.open_vertical_split()
	ChatWindow.open("vsplit")
end

function Interactions.open_horizontal_split()
	ChatWindow.open("hsplit")
end

function Interactions.open()
	ChatWindow.open()
end

function Interactions.open_select_window()
	SelectWindow.open()
end

function Interactions.open_message_prompt()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager not ready.")
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
			vim.notify("Conversation Manager not ready.")
			return
		end
		local ok, reason = ConversationManager.add_message({ role = "user", content = input })
		if ok then
			ConversationManager.generate_streaming_response()
		else
			vim.notify(reason or "Unknown error", vim.log.levels.WARN)
		end
	end)
end

function Interactions.open_message_prompt_for_selection()
	-- TODO: implement
	vim.notify("Not implemented yes.", vim.log.levels.WARN)
end

function Interactions.copy_selection()
	-- TODO: implement
	vim.notify("Not implemented yet.", vim.log.levels.WARN)
end

function Interactions.close_chat_window()
	ChatWindow.hide()
end

function Interactions.create_new_unlisted_conversation()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready")
		return
	end
	ConversationManager.new_unlisted_conversation()
	ChatWindow.open()
end

function Interactions.create_new_listed_conversation()
	vim.ui.input({ prompt = "New Chat:" }, function(input)
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
		ChatWindow.open()
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
				local ok, msg = ConversationManager.rename_listed_conversation(conversation.name, input)
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
			vim.notify("Conversation Manager is not ready")
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
		vim.notify("Conversation Manager is not ready")
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.level.INFO)
		return
	end
	ConversationManager.delete_last_message()
end

function Interactions.generate_response()
	if not ConversationManager.is_ready() then
		vim.notify("Conversation Manager is not ready")
		return
	end
	if not ConversationManager.has_conversation() then
		vim.notify("No current conversation", vim.log.level.INFO)
		return
	end
	ConversationManager.generate_streaming_response()
end

function Interactions.scroll_to_bottom()
	ChatWindow.scroll_to_bottom()
end

return Interactions
