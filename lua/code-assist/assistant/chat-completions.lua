local ChatCompletions = {}

local PluginOptions = require("code-assist.options")
local ChatCompletionDecoder = require("code-assist.assistant.interface.chat-completion-decoder")
local Curl = require("plenary.curl")

local data_path = PluginOptions.data_path
local temp_file = data_path .. "/cc-temp.json"

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
	-- TODO: implement plenary posting
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

	vim.fn.writefile({ payload }, temp_file)

	--- @type ChatCompletionResponseStatus
	local status = {
		chunks = {},
		streamed = true,
		complete = false,
	}

	Curl.post("https://api.openai.com/v1/chat/completions", {
		body = temp_file,
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
		},
		raw = { "-s" },
		stream = vim.schedule_wrap(function(err, data)
			if err then
				vim.notify("Http response error: " .. err, vim.log.levels.ERROR)
				return
			end
			if status.complete then
				return
			end
			local decode_ok, new_chunk_or_error_msg, new_complete =
					pcall(ChatCompletionDecoder.decode_chat_completion_chunk, data)
			if decode_ok then
				local new_chunk = new_chunk_or_error_msg
				if new_chunk then
					table.insert(status.chunks, new_chunk)
				end
				status.complete = new_complete
				local callback_ok, callback_error_msg = pcall(on_chunks_ready, status, { new_chunk })
				if not callback_ok then
					vim.notify(callback_error_msg, vim.log.levels.ERROR)
				end
			else
				local error_msg = new_chunk_or_error_msg --[[@as string]]
				vim.notify(error_msg, vim.log.levels.ERROR)
			end
		end),
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				vim.notify("Http response error: " .. response.status, vim.log.levels.ERROR)
			end
			status.complete = true
			if on_finish then
				local ok, reason = pcall(on_finish, status)
				if not ok then
					vim.notify(reason, vim.log.levels.ERROR)
				end
			end
		end),
	})

	return status
end

return ChatCompletions
