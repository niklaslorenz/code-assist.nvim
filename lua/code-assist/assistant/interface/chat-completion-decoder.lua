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
	-- TODO: Use the Parsing.try_parse_array function
	local choices_data = Parsing.try_get_optional("choices", "table", data)
	--- @type ChatCompletionChunkChoice[]
	local choices = {}

	if choices_data then
		for _, cd in ipairs(choices_data) do
			local delta_data = Parsing.try_get("delta", "table", cd)
			local tool_calls_data = Parsing.try_get_optional("tool_calls", "table", delta_data)
			--- @type ChatCompletionChunkToolCall[]
			local tool_calls = {}
			if tool_calls_data then
				for _, td in ipairs(tool_calls_data) do
					--- @type ChatCompletionChunkToolCall
					local tool_call = {
						arguments = Parsing.try_get("arguments", "string", td),
						id = Parsing.try_get("id", "string", td),
						index = Parsing.try_get_number("index", "integer", td),
						name = Parsing.try_get("name", "string", td),
					}
					table.insert(tool_calls, tool_call)
				end
			end

			--- @type ChatCompletionChunkDelta
			local delta = {
				role = Parsing.try_get_optional("role", "string", delta_data),
				content = Parsing.try_get_optional("content", "string", delta_data),
				tool_calls = tool_calls,
				refusal = Parsing.try_get_optional("refusal", "string", delta_data),
			}
			--- @type ChatCompletionChunkChoice
			local choice = {
				index = Parsing.try_get_number("index", "integer", cd),
				delta = delta,
				finish_reason = Parsing.try_get_optional("finish_reason", "string", cd),
			}
			table.insert(choices, choice)
		end
	end

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

--- @param data string[] An array of data lines
--- @param buffer string? The previous incomplete data line
--- @return ChatCompletionChunk[] chunks, string? buffer, boolean finished
function ChatCompletionDecoder.decode_chat_completion_chunks(data, buffer)
	--- @type ChatCompletionChunk[]
	local chunks = {}

	for i, line in ipairs(data) do
		if line and line ~= "" then
			if buffer then
				line = buffer .. line
				buffer = nil
			end
			if line:match("^data: ") then
				local line_data = line:sub(7)
				if line_data == "[DONE]" then
					return chunks, nil, true
				end
				local ok, decoded = pcall(vim.fn.json_decode, line_data)
				if ok then
					local chunk = extract_chunk(decoded)
					table.insert(chunks, chunk)
				else
					buffer = line
				end
			else
				buffer = line
				if string.len(line) > 6 then
					print("Error context: " .. line)
					error("Error decoding response data: Wrong prefix.")
				end
			end
		end
	end
	return chunks, buffer, false
end

return ChatCompletionDecoder
