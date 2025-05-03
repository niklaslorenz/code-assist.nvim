--- @class CodeAssistOptions
local Options = {
	--- @type string
	model = "gpt-4o-mini",
	--- @type string
	system_message = "You are a helpful programming assistant.",
	--- @type string
	user_chat_color = "#a3be8c",
	--- @type string
	assistant_chat_color = "#88c0d0",
	--- @type string
	data_path = vim.fn.stdpath("data") .. "/code-assist",
	--- @type string
	default_sort_order = "last",
	--- @type WindowOrientation
	default_window_orientation = "float",
	--- @type integer?
	max_context_length = nil,
	--- @type number
	relative_chat_height = 0.3,
	--- @type number
	relative_chat_width = 0.3,
	--- @type number
	relative_chat_input_height = 0.3,
	--- @type number
	relative_chat_input_width = 0.3,
}

return Options
