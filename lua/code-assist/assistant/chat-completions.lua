local M = {}

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

M.create_response = function(model, messages)
	local payload = vim.fn.json_encode({
		model = model,
		messages = messages,
	})
	local reply = nil
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
				reply = decoded.choices[1].message.content -- TODO: This is async aparently, the function always returns nil
				-- TODO: Create a better way to append messages to the current conversation and call it directly
			end
		end,
	})
	return reply
end

return M
