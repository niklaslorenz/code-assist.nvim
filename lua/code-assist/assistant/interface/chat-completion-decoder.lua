local ChatCompletionDecoder = {}

local Parsing = require("code-assist.assistant.interface.parsing")

--- @param data any
--- @return Message
function ChatCompletionDecoder.decode_chat_completion(data)
	-- TODO: implement real decoding to return an entire chat completion
	-- WARN: This is a semi working stub for returning message content
	local resp = table.concat(data, "")
	local ok, decoded = pcall(vim.fn.json_decode, resp)
	if ok and decoded and decoded.choices and decoded.choices[1] then
		local reply = decoded.choices[1].message.content
		return { role = "assistant", content = reply }
	else
		error("Error parsing chat completion")
	end
end

--- @param data any
--- @return ChatCompletionChunk
local function extract_chunk(data)
	--- @type ChatCompletionChunkChoice[]
	local choices = Parsing.parse_array("choices", "table", data, function(choice)
		local delta_data = Parsing.try_get("delta", "table", choice)
		local tool_calls = Parsing.parse_array("tool_calls", "table", choice, function(tool_call)
			--- @type ChatCompletionChunkToolCall
			local created = {
				arguments = Parsing.try_get("arguments", "string", tool_call),
				id = Parsing.try_get("id", "string", tool_call),
				index = Parsing.try_get_number("index", "integer", tool_call),
				name = Parsing.try_get("name", "string", tool_call),
			}
			return created
		end, true, true) or {} --[=[@as ChatCompletionChunkToolCall[]]=]
		--- @type ChatCompletionChunkDelta
		local delta = {
			role = Parsing.try_get_optional("role", "string", delta_data),
			content = Parsing.try_get_optional("content", "string", delta_data),
			tool_calls = tool_calls,
			refusal = Parsing.try_get_optional("refusal", "string", delta_data),
		}
		--- @type ChatCompletionChunkChoice
		local created = {
			index = Parsing.try_get_number("index", "integer", choice),
			delta = delta,
			finish_reason = Parsing.try_get_optional("finish_reason", "string", choice),
		}
		return created
	end, true, true) or {} --[=[@as ChatCompletionChunkChoice[]]=]
	--- @type ChatCompletionChunk
	local chunk = {
		choices = choices,
		created = Parsing.try_get_number("created", "integer", data),
		id = Parsing.try_get("id", "string", data),
		model = Parsing.try_get("model", "string", data),
		system_fingerprint = Parsing.try_get("system_fingerprint", "string", data),
	}
	return chunk
end

--- @param line string
--- @return ChatCompletionChunk? chunk, boolean finished
function ChatCompletionDecoder.decode_chat_completion_chunk(line)
	if not line or line == "" then
		return nil, false
	end
	if not line:match("^data: ") then
		error("Wrong data chunk format")
	end
	local data = line:sub(7)
	if data == "[DONE]" then
		return nil, true
	end
	local decoded = vim.fn.json_decode(data)
	return extract_chunk(decoded), false
end

return ChatCompletionDecoder
