-- Handles on‑disk storage of conversations

local M = {}
local fn = vim.fn
local data_path = fn.stdpath("data") .. "/code-assist"
local conv_path = data_path .. "/conversations"

-- Ensure our directories exist
local function ensure_dir(path)
	if fn.isdirectory(path) == 0 then
		fn.mkdir(path, "p")
	end
end

function M.setup()
	ensure_dir(data_path)
	ensure_dir(conv_path)
end

-- List all conversation names (filenames without .json)
function M.list()
	local files = fn.readdir(conv_path)
	local convs = {}
	for _, file in ipairs(files) do
		if file:match("%.json$") then
			table.insert(convs, file:sub(1, -6))
		end
	end
	table.sort(convs)
	return convs
end

-- Load messages array from disk
function M.load(name)
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 1 then
		local content = fn.readfile(fname)
		local ok, data = pcall(fn.json_decode, table.concat(content, "\n"))
		if ok and data.messages then
			return data.messages
		end
	end
	return nil
end

-- Save messages array to disk
function M.save(name, messages)
	local fname = conv_path .. "/" .. name .. ".json"
	local data = { messages = messages }
	fn.writefile({ fn.json_encode(data) }, fname)
end

-- Create a brand‑new conversation
function M.new_conversation()
	local name = os.date("%Y-%m-%d_%H-%M-%S")
	local messages = {
		{ role = "system", content = "You are a helpful programming assistant." },
	}
	M.save(name, messages)
	return name, messages
end

return M
