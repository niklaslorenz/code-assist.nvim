local Streaming = {}

local data_path = vim.fn.stdpath("data") .. "/code-assist"

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- @param name string
--- @param expected_type string
--- @param data any
--- @return unknown|nil
local function try_get_optional(name, expected_type, data)
	local value = data[name]
	if not value or value == vim.NIL then
		return nil
	end
	if type(value) ~= expected_type then
		error(
			"Invalid property type for property "
			.. name
			.. ": Expected "
			.. expected_type
			.. " but got "
			.. type(value)
		)
	end
	return value
end

--- @param name string
--- @param expected_type string
--- @param data any
--- @return unknown
local function try_get(name, expected_type, data)
	local value = try_get_optional(name, expected_type, data)
	if not value then
		error("Invalid nil value for property: " .. name)
	end
	return value
end

--- @param name string
--- @param expected_type string
--- @param data any
--- @return number
local function try_get_number(name, expected_type, data)
	local value = try_get(name, "number", data)
	local actual_type = math.floor(value) == value and "integer" or "float"
	if actual_type ~= expected_type then
		error(
			"Invalid number type for property " .. name .. ": Expected " .. expected_type .. " but got " .. actual_type
		)
	end
	return value
end

--- @return ChatCompletionChunk
local function extract_chunk_from_json(data)
	local choices_data = try_get_optional("choices", "table", data)
	--- @type ChatCompletionChunkChoice[]
	local choices = {}

	if choices_data then
		for _, cd in ipairs(choices_data) do
			local delta_data = try_get("delta", "table", cd)
			local tool_calls_data = try_get_optional("tool_calls", "table", delta_data)
			--- @type ChatCompletionChunkToolCall[]
			local tool_calls = {}
			if tool_calls_data then
				for _, td in ipairs(tool_calls_data) do
					--- @type ChatCompletionChunkToolCall
					local tool_call = {
						arguments = try_get("arguments", "string", td),
						id = try_get("id", "string", td),
						index = try_get_number("index", "integer", td),
						name = try_get("name", "string", td),
					}
					table.insert(tool_calls, tool_call)
				end
			end

			--- @type ChatCompletionChunkDelta
			local delta = {
				role = try_get_optional("role", "string", delta_data),
				content = try_get_optional("content", "string", delta_data),
				tool_calls = tool_calls,
				refusal = try_get_optional("refusal", "string", delta_data),
			}
			--- @type ChatCompletionChunkChoice
			local choice = {
				index = try_get_number("index", "integer", cd),
				delta = delta,
				finish_reason = try_get_optional("finish_reason", "string", cd),
			}
			table.insert(choices, choice)
		end
	end

	--- @type ChatCompletionChunk
	local chunk = {
		choices = choices,
		created = try_get_number("created", "integer", data),
		id = try_get("id", "string", data),
		model = try_get("model", "string", data),
		system_fingerprint = try_get("system_fingerprint", "string", data),
	}
	return chunk
end

--- @param data string[] An array of data lines
--- @param buffer string? The previous incomplete data line
--- @return ChatCompletionChunk[] chunks, string? buffer, boolean finished
function Streaming.decode_chat_completion_chunks(data, buffer)
	--- @type ChatCompletionChunk[]
	local chunks = {}

	for i, line in ipairs(data) do
		if line and line ~= "" then
			local slice = nil
			if buffer then
				slice = buffer .. line
				buffer = nil
			elseif line:match("^data: ") then
				slice = line:sub(7)
			else
				error("Error decoding response data: Wrong prefix.")
			end
			if slice == "[DONE]" then
				return chunks, nil, true
			end
			local ok, decoded = pcall(vim.fn.json_decode, slice)
			if ok then
				local chunk = extract_chunk_from_json(decoded)
				table.insert(chunks, chunk)
			else
				buffer = slice
			end
		end
	end
	return chunks, buffer, false
end

--- @param status ChatCompletionResponseStatus
--- @param new_chunks ChatCompletionChunk[]
local function handleStreamingTestMessage(status, new_chunks)
	--- @type string[]
	local messages = {}
	for _, chunk in ipairs(new_chunks) do
		--- @type ChatCompletionChunkChoice
		local choice = chunk.choices[1]
		local message = choice.delta.content
		-- TODO: Add other message content like role
		table.insert(messages, message)
	end
	print(table.concat(messages))
end
function Streaming.test()
	--- @type Message[]
	local messages = {
		{ role = "system", content = "You are a helpful AI assistant." },
		{ role = "user",   content = "Hello, who are you?" },
	}
	local test_result = Streaming.post_request(messages, handleStreamingTestMessage)
end

return Streaming
