local Util = require("code-assist.util")
local Future = require("code-assist.future")
local PluginOptions = require("code-assist.options")
local Parser = require("code-assist.api.parser.chat-completion")
local Curl = require("plenary.curl")

local data_path = PluginOptions.data_path
local temp_file = data_path .. "/cc-temp.json"

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

local ChatCompletionInterface = {}

--- Generate a response for a given message array and a specific model.
--- The callback is called, when the response is ready.
--- @param model string
--- @param messages ChatCompletionMessage[]
--- @param callback fun(reply: ChatCompletion)
--- @return Future<ChatCompletion?> status
ChatCompletionInterface.post_request = function(model, messages, callback)
	local payload = vim.fn.json_encode({
		model = model,
		messages = Parser.encode_message_array(messages),
	})
	--- @type Future<ChatCompletion?>
	local status = Future:new()
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
			local decode_ok, completion = pcall(Parser.parse_chat_completion, data)
			if decode_ok then
				local callback_ok, error_msg = pcall(callback, completion)
				if not callback_ok then
					vim.notify("Error in post_request callback" .. error_msg, vim.log.levels.ERROR)
				end
				status:complete(completion)
			else
				vim.notify("Error in decoding chat completion: " .. completion, vim.log.levels.ERROR)
				status:complete(nil)
			end
		end,
	})
	return status
end

--- @param agent_name string?
--- @param messages ChatCompletionMessage[]
--- @param on_chunk_ready fun(new_chunk: ChatCompletion)
--- @param on_finish? fun(status: ChatCompletion?)
--- @return Future<ChatCompletion?> status
function ChatCompletionInterface.post_streaming_request(agent_name, messages, on_chunk_ready, on_finish)
	local agent = Util.get_agent(agent_name)

	local payload = vim.fn.json_encode({
		model = agent.model,
		messages = Parser.encode_message_array(messages, agent.system_message),
		reasoning_effort = agent.reasoning_effort,
		stream = true,
	})

	vim.fn.writefile({ payload }, temp_file)

	--- @type Future<ChatCompletion?>
	local result = Future:new()

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
			if result.completed then
				return
			end
			local decode_ok, new_chunk_or_error_msg, _ = pcall(Parser.parse_chat_completion_chunk, data)
			if decode_ok then
				local new_chunk = new_chunk_or_error_msg
				if new_chunk then
					local callback_ok, callback_error_msg = pcall(on_chunk_ready, new_chunk)
					if not callback_ok then
						vim.notify("Error in on_chunk_ready callback: " .. callback_error_msg, vim.log.levels.ERROR)
					end
				end
			else
				local error_msg = new_chunk_or_error_msg --[[@as string]]
				vim.notify("Error while decoding chat completion chunk: " .. error_msg, vim.log.levels.ERROR)
			end
		end),
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				vim.notify("Http response error: " .. response.status, vim.log.levels.ERROR)
			end
			result:complete(nil)
			if on_finish then
				local ok, reason = pcall(on_finish, nil)
				if not ok then
					vim.notify("Error in on_finish callback: " .. reason, vim.log.levels.ERROR)
				end
			end
		end),
	})
	return result
end

return ChatCompletionInterface
