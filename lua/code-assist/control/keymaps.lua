local Keymaps = {}

local Interactions = require("code-assist.control.interactions")

--- @param key string
--- @param func fun()
--- @param buf integer?
--- @param mode string | string[] | nil
local function add_keymap(key, func, buf, mode)
	mode = mode or "n"
	vim.keymap.set(mode, key, function()
		func()
	end, { buffer = buf })
end

function Keymaps.setup_global_keymaps()
	add_keymap("<leader>aN", Interactions.create_new_listed_conversation)
	add_keymap("<leader>an", Interactions.create_new_unlisted_conversation)
	add_keymap("<leader>as", Interactions.open_select_window)
	add_keymap("<leader>av", Interactions.open_vertical_split)
	add_keymap("<leader>ah", Interactions.open_horizontal_split)
	add_keymap("<leader>af", Interactions.open_floating_window)
	add_keymap("<leader>ao", Interactions.open)
	add_keymap("<leader>am", Interactions.open_message_prompt)
	add_keymap("<leader>ac", Interactions.copy_selection, nil, "v")
	add_keymap("<leader>am", Interactions.open_message_prompt_for_selection, nil, "v")
	add_keymap("<leader>ab", Interactions.scroll_to_bottom, nil, { "n", "v" })
end

--- @param window integer buffer index
function Keymaps.setup_chat_buffer_keymaps(window)
	add_keymap("q", Interactions.close_chat_window, window)
	add_keymap("<CR>", Interactions.open_message_prompt, window)
	add_keymap("<leader>ar", Interactions.rename_current_conversation, window)
	add_keymap("<leader>adc", Interactions.delete_current_conversation, window)
	add_keymap("<leader>adm", Interactions.delete_last_message, window)
	add_keymap("<leader>ag", Interactions.generate_response, window)
end

return Keymaps
