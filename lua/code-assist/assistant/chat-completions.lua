local ChatCompletions = {}

local Streaming = require("code-assist.assistant.interface.streaming")

--- @class ChatCompletionResponseStatus
--- @field complete boolean
--- @field chunks ChatCompletionChunk[]

--- @class ChatCompletionChunkToolCall
--- @field index integer
--- @field id string
--- @field name string
--- @field arguments string

--- @class ChatCompletionChunkDelta
--- @field content string?
--- @field refusal string?
--- @field role string?
--- @field tool_calls ChatCompletionChunkToolCall[]

--- @class ChatCompletionChunkChoice
--- @field index integer
--- @field finish_reason string?
--- @field delta ChatCompletionChunkDelta

--- @class ChatCompletionChunk
--- @field id string
--- @field choices ChatCompletionChunkChoice[]
--- @field created integer
--- @field model string
--- @field system_fingerprint string

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- Generate a response for a given message array and a specific model.
--- The callback is called, when the response is ready.
--- @param model string
--- @param messages Message[]
--- @param callback fun(reply: Message)
ChatCompletions.post_request = function(model, messages, callback)
	local payload = vim.fn.json_encode({
		model = model,
		messages = messages,
	})
	vim.fn.jobstart({
		"curl",
		"-s",
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. api_key,
		"-d",
		payload,
	}, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			local resp = table.concat(data, "")
			local ok, decoded = pcall(vim.fn.json_decode, resp)
			if ok and decoded and decoded.choices and decoded.choices[1] then
				local reply = decoded.choices[1].message.content
				callback({ role = "assistant", content = reply })
			end
		end,
	})
end

--- @param model string
--- @param messages Message[]
--- @param on_chunks_ready fun(status: ChatCompletionResponseStatus, new_chunks: ChatCompletionChunk[])
--- @param on_finish? fun(status: ChatCompletionResponseStatus)
--- @return ChatCompletionResponseStatus
function ChatCompletions.post_streaming_request(model, messages, on_chunks_ready, on_finish)
	local payload = vim.fn.json_encode({
		model = model,
		messages = messages,
		stream = true,
	})
	--- @type string|nil
	local buffer = nil
	--- @type ChatCompletionResponseStatus
	local status = {
		chunks = {},
		complete = false,
	}

	vim.fn.jobstart({
		"curl",
		"-s",
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. api_key,
		"-d",
		payload,
	}, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if status.complete then
				return
			end
			local new_chunks, new_buffer, new_complete = Streaming.decode(data, buffer)
			for _, chunk in ipairs(new_chunks) do
				table.insert(status.chunks, chunk)
			end
			status.complete = new_complete
			buffer = new_buffer
			on_chunks_ready(status, new_chunks)
			if status.complete and on_finish then
				on_finish(status)
			end
		end,
	})
	return status
end

return ChatCompletions
