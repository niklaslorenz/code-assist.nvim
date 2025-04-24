local Streaming = {}

local data_path = vim.fn.stdpath("data") .. "/code-assist"

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

function Streaming.test()
	--- @type Message[]
	local messages = {
		{ role = "system", content = "You are a helpful AI assistant." },
		{ role = "user",   content = "Hello, who are you?" },
	}
	Streaming.post_request(messages)
end

--- @param data string[]
--- @param buffer string?
local function decode(data, buffer)
	local chunks = {}

	for _, line in ipairs(data) do
		local slice = nil
		if buffer then
			slice = buffer .. line
		else
			if line:match("^data: ") then
				slice = line:sub(6)
			else
				error("Error decoding response data: Wrong prefix.")
			end
		end
		if slice then
			if slice == "[DONE]" then
				return chunks
			end
		end
	end
	warn("Missing response sentinel.")
end
--- @param rawData string[]
local function decodeChunks(rawData)
	local chunks = {} -- Table to accumulate completed chunks
	local buffer = "" -- Buffer to hold incomplete lines or data

	for _, line in ipairs(rawData) do
		-- Ensure that we are processing lines correctly
		if line:match("^data: ") then
			local json_data = line:sub(7) -- Remove 'data: ' prefix

			if json_data and json_data ~= "[DONE]" then
				buffer = buffer .. json_data -- Accumulate data

				-- Check if the buffered data can be decoded
				local success, result = pcall(function()
					return require("cjson").decode(buffer)
				end)

				if success and result.choices and result.choices[1].delta.content then
					-- Successfully decoded a JSON chunk
					table.insert(chunks, result.choices[1].delta.content) -- Add content to chunks
					buffer = ""                                      -- Clear buffer after processing
				end
			end
		end

		-- If an incoming line does not match 'data: ', it may be an error message or other information
		if line and not line:match("^data: ") then
			print("Unexpected line: " .. line) -- Print unexpected lines for debugging
		end
	end

	return chunks
end

-- Example of usage in the callback
local function handleOutput(data)
	local chunks = decodeChunks(data) -- Decode using the function

	for _, chunk in ipairs(chunks) do
		print(chunk) -- Output the chunks as they are decoded
	end
end

--- @param messages Message[]
function Streaming.post_request(messages)
	local fname = data_path .. "/test.json"
	if vim.fn.filereadable(fname) ~= 0 then
		vim.fn.delete(fname)
	end
	local payload = vim.fn.json_encode({
		model = "gpt-4o-mini",
		messages = messages,
		stream = true,
	})
	local iterator = 0
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
			vim.fn.writefile({ "--- chunk " .. iterator .. " ---" }, fname, "a")
			iterator = iterator + 1
			vim.fn.writefile(data, fname, "a")
			local resp = table.concat(data, "")
			local ok, decoded = pcall(vim.fn.json_decode, resp)
			if ok and decoded and decoded.choices and decoded.choices[1] then
				local reply = decoded.choices[1].message.content
			end
		end,
	})
end

return Streaming
