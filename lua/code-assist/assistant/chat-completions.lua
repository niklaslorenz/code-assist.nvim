local ChatCompletions = {}

local PluginOptions = require("code-assist.options")
local Interface = require("code-assist.assistant.interface.chat-completions")
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
--- @param messages ConversationMessage[]
--- @param callback fun(reply: ConversationMessage)
--- @return ConversationManagerStatus status
ChatCompletions.post_request = function(model, messages, callback)
	local payload = vim.fn.json_encode({
		model = model,
		messages = Interface.encode_message_array(messages),
	})
	--- @type ConversationManagerStatus
	local status = {
		items = {},
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
			local decode_ok, message = pcall(Interface.decode_chat_completion, data)
			if decode_ok then
				table.insert(status.items, message)
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
--- @param messages ConversationMessage[]
--- @param on_chunk_ready fun(status: ChatCompletionResponseStatus, new_chunk: ChatCompletionChunk)
--- @param on_finish? fun(status: ChatCompletionResponseStatus)
--- @return ConversationManagerStatus status
function ChatCompletions.post_streaming_request(model, messages, on_chunk_ready, on_finish)
	local payload = vim.fn.json_encode({
		model = model,
		messages = Interface.encode_message_array(messages),
		stream = true,
	})

	vim.fn.writefile({ payload }, temp_file)

	--- @type ConversationManagerStatus
	local status = {
		items = {},
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
			local decode_ok, new_chunk_or_error_msg, new_complete = pcall(Interface.decode_chat_completion_chunk, data)
			if decode_ok then
				local new_chunk = new_chunk_or_error_msg
				if new_chunk then
					table.insert(status.items, new_chunk)
					local callback_ok, callback_error_msg = pcall(on_chunk_ready, status, new_chunk)
					if not callback_ok then
						vim.notify(callback_error_msg, vim.log.levels.ERROR)
					end
				end
				status.complete = new_complete
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
