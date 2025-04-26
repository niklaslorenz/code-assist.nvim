local ChatCompletions = {}

local ChatCompletionDecoder = require("code-assist.assistant.interface.chat-completion-decoder")

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- Generate a response for a given message array and a specific model.
--- The callback is called, when the response is ready.
--- @param model string
--- @param messages Message[]
--- @param callback fun(reply: Message)
--- @return ChatCompletionResponseStatus status
ChatCompletions.post_request = function(model, messages, callback)
	local payload = vim.fn.json_encode({
		model = model,
		messages = messages,
	})
	--- @type ChatCompletionResponseStatus
	local status = {
		complete = false,
		streamed = false,
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
		stdout_buffered = true,
		on_stdout = function(_, data)
			local decode_ok, message = pcall(ChatCompletionDecoder.decode_chat_completion, data)
			if decode_ok then
				status.message = message
				local callback_ok, error_msg = pcall(callback, message)
				if not callback_ok then
					print("Error in post_request callback: ")
					print(error_msg)
				end
			else
				print("Error in decoding chat completion: ")
				print(message)
			end
			status.complete = true
		end,
	})
	return status
end

--- @param model string
--- @param messages Message[]
--- @param on_chunks_ready fun(status: ChatCompletionResponseStatus, new_chunks: ChatCompletionChunk[])
--- @param on_finish? fun(status: ChatCompletionResponseStatus)
--- @return ChatCompletionResponseStatus status
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
		streamed = true,
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
			local decode_ok, new_chunks_or_error_msg, new_buffer, new_complete =
					pcall(ChatCompletionDecoder.decode_chat_completion_chunks, data, buffer)
			if decode_ok then
				local new_chunks = new_chunks_or_error_msg
				for _, chunk in ipairs(new_chunks) do
					table.insert(status.chunks, chunk)
				end
				status.complete = new_complete
				buffer = new_buffer
				local callback_ok, callback_error_msg = pcall(on_chunks_ready, status, new_chunks)
				if not callback_ok then
					print("Error in post_streaming_request chunk callback:")
					print(callback_error_msg)
				end
			else
				local error_msg = new_chunks_or_error_msg
				print("Error in decoding chat completion chunks:")
				print(error_msg)
			end
			if status.complete and on_finish then
				status.complete = true
				local finish_callback_ok, error_msg = pcall(on_finish, status)
				if not finish_callback_ok then
					print("Error in post_streaming_request finish callback:")
					print(error_msg)
				end
			end
		end,
		on_finish = function(_)
			status.complete = true
		end,
	})
	return status
end

return ChatCompletions
