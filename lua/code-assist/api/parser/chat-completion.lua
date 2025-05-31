local ChatCompletionParser = {}

local Parsing = require("code-assist.api.parser.parsing")

--- @param data any
--- @return ChatCompletionToolCall
local function parse_tool_call(data)
	--- @type ChatCompletionToolCall
	local tool_call = {
		arguments = Parsing.try_get("arguments", "string", data),
		id = Parsing.try_get("id", "string", data),
		index = Parsing.try_get_number("index", "integer", data),
		name = Parsing.try_get("name", "string", data),
	}
	return tool_call
end

--- @param data any|nil
local function parse_delta(data)
	--- @type {
	--- content: string?,
	--- refusal: string?,
	--- role: string?,
	--- tool_calls: ChatCompletionToolCall[],
	--- }
	local delta = {
		content = Parsing.try_get_optional("content", "string", data),
		refusal = Parsing.try_get_optional("refusal", "string", data),
		role = Parsing.try_get_optional("role", "string", data),
		tool_calls = Parsing.try_parse_optional_array("tool_calls", "table", data, parse_tool_call, true) or {},
	}
	return delta
end

--- @param data any
local function parse_chunk_choice(data)
	--- @type {
	--- content: string?,
	--- refusal: string?,
	--- role: string?,
	--- tool_calls: ChatCompletionToolCall[],
	--- }
	local delta = Parsing.try_parse_optional_object("delta", data, parse_delta) or {}
	--- @type {
	--- content: string?,
	--- refusal: string?,
	--- role: string?,
	--- tool_calls: ChatCompletionToolCall[],
	--- finish_reason: string?,
	--- }
	local choice = {
		content = delta.content,
		refusal = delta.refusal,
		role = delta.role,
		tool_calls = delta.tool_calls,
		finish_reason = Parsing.try_get_optional("finish_reason", "string", data),
	}
	return choice
end

--- @param data any
local function parse_usage(data)
	--- @type {completion_tokens: integer, prompt_tokens: integer}
	local usage = {
		completion_tokens = Parsing.try_get_number("completion_tokens", "integer", data),
		prompt_tokens = Parsing.try_get_number("prompt_tokens", "integer", data),
	}
	return usage
end

--- @param data any
local function parse_completion(data)
	local choices = Parsing.try_parse_optional_array("choices", "table", data, parse_chunk_choice, true)
	if #choices > 1 then
		vim.notify("Expected not more than one completion choice but got: " .. #choices, vim.log.levels.WARN)
	end
	--- @type {
	--- content: string?,
	--- refusal: string?,
	--- role: string?,
	--- tool_calls: ChatCompletionToolCall[],
	--- finish_reason: string?,
	--- }
	local choice = choices[1] or {}
	--- @type ChatCompletion
	local chunk = {
		content = choice.content,
		refusal = choice.refusal,
		role = choice.role,
		tool_calls = choice.tool_calls,
		finish_reason = choice.finish_reason,
		created = Parsing.try_get_number("created", "integer", data),
		id = Parsing.try_get("id", "string", data),
		model = Parsing.try_get("model", "string", data),
		system_fingerprint = Parsing.try_get_optional("system_fingerprint", "string", data) or "<undefined>",
		usage = Parsing.try_parse_optional_object("usage", data, parse_usage),
	}
	return chunk
end

--- @param data string
--- @return ChatCompletion
function ChatCompletionParser.parse_chat_completion(data)
	local decoded = vim.fn.json_decode(data)
	assert(decoded.object == "chat.completion")
	return parse_completion(decoded)
end

--- @param line string
--- @return ChatCompletion? chunk, boolean finished
function ChatCompletionParser.parse_chat_completion_chunk(line)
	if not line or line == "" then
		return nil, false
	end
	if not line:match("^data: ") then
		print("Line: " .. line)
		error("Wrong data chunk format")
	end
	local data = line:sub(7)
	if data == "[DONE]" then
		return nil, true
	end
	local decoded = vim.fn.json_decode(data)
	assert(decoded.object == "chat.completion.chunk")
	return parse_completion(decoded), false
end

--- @param messages ChatCompletionMessage[]
function ChatCompletionParser.encode_message_array(messages)
	--- @type {role: ChatCompletionRole, content: string}[]
	local encoded = {}
	for i, message in ipairs(messages) do
		encoded[i] = {
			role = message.role,
			content = message.text,
		}
	end
	return encoded
end

return ChatCompletionParser
