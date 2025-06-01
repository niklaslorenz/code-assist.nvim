local Keymaps = {}

local Interactions = require("code-assist.control.interactions")
local Windows = require("code-assist.ui.window-instances")
local Util = require("code-assist.util")

local add_keymap = Util.set_keymap

function Keymaps.setup_global_keymaps()
	add_keymap("<leader>a", nil, "🗨 Code Assist", nil, { "n", "v" })

	add_keymap("<leader>an", nil, "New", nil, { "n", "v" })
	add_keymap("<leader>anl", Interactions.create_new_listed_conversation, "Listed conversation", nil, { "n", "v" })
	add_keymap("<leader>anu", Interactions.create_new_unlisted_conversation, "Unlisted conversation", nil, { "n", "v" })
	add_keymap("<leader>anp", Interactions.create_new_project_conversation, "Project conversation", nil, { "n", "v" })

	add_keymap("<leader>as", nil, "Select Conversation", nil, { "n", "v" })
	add_keymap(
		"<leader>asl",
		Interactions.open_listed_conversations_selection,
		"Listed conversation",
		nil,
		{ "n", "v" }
	)
	add_keymap(
		"<leader>asp",
		Interactions.open_project_conversations_selection,
		"Project conversation",
		nil,
		{ "n", "v" }
	)

	add_keymap("<leader>aq", Interactions.close_chat_window, "Close chat window", nil, { "n", "v" })
	add_keymap("<leader>av", Interactions.open_vertical_split, "Open vertical split", nil, { "n", "v" })
	add_keymap("<leader>ah", Interactions.open_horizontal_split, "Open horizontal split", nil, { "n", "v" })
	add_keymap("<leader>af", Interactions.open_floating_window, "Open floating window", nil, { "n", "v" })
	add_keymap("<leader>ao", Interactions.open, "Open chat window", nil, { "n", "v" })
	add_keymap("<leader>am", Interactions.open_message_prompt, "Open message prompt")
	add_keymap("<leader>ac", Interactions.copy_selection, "Copy selection", nil, { "n", "v" })
	add_keymap("<leader>ag", Interactions.generate_response, "Generate response")
	add_keymap(
		"<leader>am",
		Interactions.open_message_prompt_for_selection,
		"Open prompt for selection",
		nil,
		{ "n", "v" }
	)
	add_keymap("<leader>ab", Interactions.scroll_to_bottom, "Scroll to bottom", nil, { "n", "v" })
end

--- @param buffer integer buffer index
function Keymaps.setup_chat_buffer_keymaps(buffer)
	add_keymap("q", Interactions.close_chat_window, "Close chat window", { buffer = buffer })
	add_keymap("o", Interactions.open_chat_completion_options_window, "Open Conversation Options", { buffer = buffer })
	add_keymap("<CR>", Interactions.goto_message_input, "Open message prompt", { buffer = buffer })
	add_keymap("i", Interactions.goto_message_input, "Open message prompt", { buffer = buffer })
	add_keymap("r", Interactions.rename_current_conversation, "Rename conversation", { buffer = buffer })
	add_keymap("dc", Interactions.delete_current_conversation, "Delete conversation", { buffer = buffer })
	add_keymap("dm", Interactions.delete_last_message, "Delete last message", { buffer = buffer })
	add_keymap("[c", Interactions.scroll_to_previous_begin, "previous message begin", { buffer = buffer })
	add_keymap("]c", Interactions.scroll_to_next_begin, "next message begin", { buffer = buffer })
	add_keymap("m", Interactions.open_model_select, "Select Model", { buffer = buffer })
end

--- @param buffer integer buffer index
function Keymaps.setup_chat_input_buffer_keymaps(buffer)
	add_keymap("q", Interactions.close_chat_window, "Close chat window", { buffer = buffer })
	add_keymap("<CR><CR>", function()
		Windows.ChatInput:submit()
		Windows.Chat:scroll_to_bottom()
	end, "Commit chat input", { buffer = buffer }, { "n", "v", "i" })
end

return Keymaps
