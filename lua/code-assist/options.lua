--- @class CodeAssistOptions?
--- @field default_model string?
--- @field models table<string, string>?
--- @field default_system_message string?
--- @field user_chat_color string?
--- @field assistant_chat_color string?
--- @field data_path string?
--- @field default_sort_order ConversationSorting?
--- @field max_context_length integer?
--- @field relative_chat_height number?
--- @field relative_chat_width number?
--- @field relative_chat_input_width number?
--- @field relative_chat_input_height number?
--- @field project_conversation_path string?
--- @field default_conversation_class "assistant"|"chat-completion"?
--- @field agents table<string, string>?
--- @field default_agent string?

local Options = {
	default_model = "gpt-4o-mini",
	models = {
		["gpt-4o-mini"] = "gpt-4o-mini",
		["gpt-4o"] = "gpt-4o",
		["o4-mini"] = "o4-mini",
	},
	default_system_message = "You are a helpful programming assistant.",
	agents = {},
	user_chat_color = "#a3be8c",
	assistant_chat_color = "#88c0d0",
	data_path = vim.fn.stdpath("data") .. "/code-assist",
	default_sort_order = "newest",
	default_window_orientation = "float",
	default_filter = { "system" },
	max_context_length = nil,
	relative_chat_height = 0.3,
	relative_chat_width = 0.3,
	relative_chat_input_height = 0.3,
	relative_chat_input_width = 0.3,
	project_conversation_path = ".conversations",
	default_conversation_class = "chat-completion",
	default_agent = nil,
}

return Options
