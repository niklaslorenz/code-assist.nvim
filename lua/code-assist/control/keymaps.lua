local Keymaps = {}

local Interactions = require("code-assist.control.interactions")
local Windows = require("code-assist.ui.window-instances")
local has_which_key, WhichKey = pcall(require, "which-key")

--- @param key string
--- @param func fun()?
--- @param buf integer?
--- @param mode string | string[] | nil
--- @param description string
local function add_keymap(key, func, description, buf, mode)
	mode = mode or "n"
	if has_which_key then
		WhichKey.add({
			{
				mode = mode,
				buffer = buf,
				callback = func,
				lhs = key,
				noremap = true,
				desc = description,
				silent = true,
			},
		})
	elseif func then
		vim.keymap.set(mode, key, function()
			func()
		end, { buffer = buf })
	end
end

function Keymaps.setup_global_keymaps()
	add_keymap("<leader>a", nil, "🗨 Code Assist")
	add_keymap("<leader>aq", Interactions.close_chat_window, "Close chat window", nil, { "n", "v" })
	add_keymap("<leader>aN", Interactions.create_new_listed_conversation, "New listed conversation", nil, { "n", "v" })
	add_keymap(
		"<leader>an",
		Interactions.create_new_unlisted_conversation,
		"New unlisted conversation",
		nil,
		{ "n", "v" }
	)
	add_keymap("<leader>as", Interactions.open_select_window, "Select conversation", nil, { "n", "v" })
	add_keymap("<leader>av", Interactions.open_vertical_split, "Open vertical split", nil, { "n", "v" })
	add_keymap("<leader>ah", Interactions.open_horizontal_split, "Open horizontal split", nil, { "n", "v" })
	add_keymap("<leader>af", Interactions.open_floating_window, "Open floating window", nil, { "n", "v" })
	add_keymap("<leader>ao", Interactions.open, "Open chat window", nil, { "n", "v" })
	add_keymap("<leader>am", Interactions.open_message_prompt, "Open message prompt")
	add_keymap("<leader>ac", Interactions.copy_selection, "Copy selection", nil, { "n", "v" })
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
	add_keymap("q", Interactions.close_chat_window, "Close chat window", buffer)
	add_keymap("f", Interactions.open_chat_filter_window, "Open Chat Filter", buffer)
	add_keymap("<CR>", Interactions.open_message_prompt, "Open message prompt", buffer)
	add_keymap("<leader>ar", Interactions.rename_current_conversation, "Rename conversation", buffer)
	add_keymap("<leader>adc", Interactions.delete_current_conversation, "Delete conversation", buffer)
	add_keymap("<leader>adm", Interactions.delete_last_message, "Delete last message", buffer)
	add_keymap("<leader>ag", Interactions.generate_response, "Generate response", buffer)
	add_keymap("[c", Interactions.scroll_to_previous_begin, "previous message begin", buffer)
	add_keymap("]c", Interactions.scroll_to_next_begin, "next message begin", buffer)
end

--- @param buffer integer buffer index
function Keymaps.setup_chat_input_buffer_keymaps(buffer)
	add_keymap("q", Interactions.close_chat_window, "Close chat window", buffer)
	add_keymap("<CR><CR>", function()
		Windows.ChatInput:commit()
		Windows.Chat:scroll_to_bottom()
	end, "Commit chat input", buffer, { "n", "v", "i" })
end

return Keymaps
