local Keymaps = {}

local Interactions = require("code-assist.control.interactions")
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
	add_keymap("<leader>aN", Interactions.create_new_listed_conversation, "New listed conv.", nil, { "n", "v" })
	add_keymap("<leader>an", Interactions.create_new_unlisted_conversation, "New unlisted conv.", nil, { "n", "v" })
	add_keymap("<leader>as", Interactions.open_select_window, "Select conversation", nil, { "n", "v" })
	add_keymap("<leader>av", Interactions.open_vertical_split, "Open vertical split", nil, { "n", "v" })
	add_keymap("<leader>ah", Interactions.open_horizontal_split, "Open horizontal split", nil, { "n", "v" })
	add_keymap("<leader>af", Interactions.open_floating_window, "Open floating window", nil, { "n", "v" })
	add_keymap("<leader>ao", Interactions.open, "Open chat window", nil, { "n", "v" })
	add_keymap("<leader>am", Interactions.open_message_prompt, "Open message prompt")
	add_keymap("<leader>ac", Interactions.copy_selection, "Copy selection", nil, "v")
	add_keymap("<leader>am", Interactions.open_message_prompt_for_selection, "Open message for selection", nil, "v")
	add_keymap("<leader>ab", Interactions.scroll_to_bottom, "Scroll to bottom", nil, { "n", "v" })
end

--- @param window integer buffer index
function Keymaps.setup_chat_buffer_keymaps(window)
	add_keymap("q", Interactions.close_chat_window, "Close chat window", window)
	add_keymap("<CR>", Interactions.open_message_prompt, "Open message prompt", window)
	add_keymap("<leader>ar", Interactions.rename_current_conversation, "Rename conversation", window)
	add_keymap("<leader>adc", Interactions.delete_current_conversation, "Delete conversation", window)
	add_keymap("<leader>adm", Interactions.delete_last_message, "Delete last message", window)
	add_keymap("<leader>ag", Interactions.generate_response, "Generate response", window)
end

return Keymaps
