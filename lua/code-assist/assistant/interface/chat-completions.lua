local ChatCompletionInterface = {}

local Parsing = require("code-assist.assistant.interface.parsing")
local Message = require("code-assist.conversations.message")

--- @param data any
--- @return ChatCompletionToolCall tool_call
local function decode_tool_call(data)
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
--- @return ChatCompletionDelta delta
local function decode_delta(data)
	--- @type ChatCompletionDelta
	local delta = {
		content = Parsing.try_get_optional("content", "string", data),
		refusal = Parsing.try_get_optional("refusal", "string", data),
		role = Parsing.try_get_optional("role", "string", data),
		tool_calls = Parsing.try_parse_optional_array("tool_calls", "table", data, decode_tool_call, true),
	}
	return delta
end

--- @param data any
--- @return ChatCompletionChunkChoice choice
local function decode_chunk_choice(data)
	--- @type ChatCompletionChunkChoice
	local choice = {
		delta = Parsing.try_parse_optional_object("delta", data, decode_delta),
		index = Parsing.try_get_number("index", "integer", data),
		finish_reason = Parsing.try_get_optional("finish_reason", "string", data),
	}
	return choice
end

--- @param data any
--- @return ChatCompletionUsage
local function decode_usage(data)
	--- @type ChatCompletionUsage
	local usage = {
		completion_tokens = Parsing.try_get_number("completion_tokens", "integer", data),
		prompt_tokens = Parsing.try_get_number("prompt_tokens", "integer", data),
	}
	return usage
end

--- @param data any
--- @return ChatCompletionChunk chunk
local function decode_chunk(data)
	--- @type ChatCompletionChunk
	local chunk = {
		choices = Parsing.try_parse_optional_array("choices", "table", data, decode_chunk_choice, true),
		created = Parsing.try_get_number("created", "integer", data),
		id = Parsing.try_get("id", "string", data),
		model = Parsing.try_get("model", "string", data),
		system_fingerprint = Parsing.try_get("system_fingerprint", "string", data),
		usage = Parsing.try_parse_optional_object("usage", data, decode_usage),
	}
	return chunk
end

--- @param data any
--- @return ConversationMessage
function ChatCompletionInterface.decode_chat_completion(data)
	-- TODO: implement real decoding to return an entire chat completion
	-- WARN: This is a semi working stub for returning message content
	local resp = table.concat(data, "")
	local ok, decoded = pcall(vim.fn.json_decode, resp)
	if ok and decoded and decoded.choices and decoded.choices[1] then
		local reply = decoded.choices[1].message.content
		return Message:new("assistant", "assistant", reply)
	else
		error("Error parsing chat completion")
	end
end

--- @param line string
--- @return ChatCompletionChunk? chunk, boolean finished
function ChatCompletionInterface.decode_chat_completion_chunk(line)
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
	return decode_chunk(decoded), false
end

--- @param messages ConversationMessage[]
--- @return unknown[]
function ChatCompletionInterface.encode_message_array(messages)
	local encoded = {}
	for i, message in ipairs(messages) do
		encoded[i] = {
			role = message.role,
			content = message.content,
		}
	end
	return encoded
end

return ChatCompletionInterface
