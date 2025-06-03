--- @class CodeAssistOptions?
--- Path
--- @field data_path string?
--- @field project_conversation_path string?
--- Chat Window Appearance
--- @field relative_chat_height number?
--- @field relative_chat_width number?
--- @field relative_chat_input_width number?
--- @field relative_chat_input_height number?
--- @field default_filter string[]?
--- @field default_window_orientation WindowOrientation
--- Conversations
--- @field max_context_length integer?
--- @field default_sort_order ConversationSorting?
--- @field default_conversation_class "assistant"|"chat-completion"?
--- Agents
--- @field agents ca.chat-completion.Agent[]?
--- @field default_agent string?
--- @field default_system_message string?
--- @field default_model string?

local Options = {

	--- Paths
	--- @type string
	data_path = vim.fn.stdpath("data") .. "/code-assist",
	--- @type string
	project_conversation_path = ".conversations",

	--- Chat Window Appearance
	--- @type number
	relative_chat_height = 0.3,
	--- @type number
	relative_chat_width = 0.3,
	--- @type number
	relative_chat_input_height = 0.3,
	--- @type number
	relative_chat_input_width = 0.3,
	--- @type string[]
	default_filter = { "system" },
	--- @type WindowOrientation
	default_window_orientation = "float",

	--- Conversations
	--- @type "assistant"|"chat-completion"
	default_conversation_class = "chat-completion",
	--- @type integer?
	max_context_length = nil,
	--- @type ConversationSorting
	default_sort_order = "newest",

	--- Agents
	--- @type ca.chat-completion.Agent[]
	agents = {},
	--- @type string?
	default_agent = nil,
	--- @type string
	default_system_message = "You are a helpful assistant.",
	--- @type string
	default_model = "gpt-4o-mini",
}

return Options
