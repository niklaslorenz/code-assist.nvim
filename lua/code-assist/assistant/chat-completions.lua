local ChatCompletions = {}

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- Generate a response for a given message array and a specific model.
--- The callback is called, when the response is ready.
--- @param model string
--- @param messages Message[]
--- @param callback fun(reply: Message)
ChatCompletions.create_response = function(model, messages, callback)
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

--- Generate a response for a given message array and a specific model.
--- The generated response is returned.
--- @param model string
--- @param messages Message[]
--- @return Message
ChatCompletions.await_response = function(model, messages)
	local reply = nil
	ChatCompletions.create_response(model, messages, function(message)
		reply = message
	end)
	local delay = 2
	while not reply do
		local t0 = os.clock()
		while os.clock() - t0 < delay do
		end
	end
	return reply
end

return ChatCompletions
