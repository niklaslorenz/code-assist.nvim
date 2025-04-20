-- Renders the floating chat buffer and handles I/O with OpenAI

local M = {}
local cm = require("code-assist.conversation-manager")
local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

local chat_buf, chat_win, messages, conv_name

function M.open(name, msgs)
	conv_name = name
	messages = msgs

	-- If already open, jump there
	if chat_win and vim.api.nvim_win_is_valid(chat_win) then
		vim.api.nvim_set_current_win(chat_win)
		return
	end

	-- Create centered floating window
	local w = math.floor(vim.o.columns * 0.6)
	local h = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - h) / 2)
	local col = math.floor((vim.o.columns - w) / 2)

	chat_buf = vim.api.nvim_create_buf(false, true)
	chat_win = vim.api.nvim_open_win(chat_buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.bo[chat_buf].filetype = "markdown"
	vim.bo[chat_buf].bufhidden = "wipe"

	-- Populate existing messages
	local lines = {}
	for _, msg in ipairs(messages) do
		local prefix = (msg.role == "user" and "You: " or msg.role == "assistant" and "Assistant: " or "")
		table.insert(lines, prefix .. msg.content)
	end
	vim.api.nvim_buf_set_lines(chat_buf, 0, -1, false, lines)

	-- Close & save on q
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(chat_win, true)
		cm.save(conv_name, messages)
	end, { buffer = chat_buf })

	-- <Enter> to send a prompt
	vim.keymap.set("n", "<CR>", function()
		vim.ui.input({ prompt = "You: " }, function(input)
			if not input then
				return
			end

			-- Append user message
			table.insert(messages, { role = "user", content = input })
			vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "You: " .. input })
			cm.save(conv_name, messages)

			-- Call OpenAI
			local payload = vim.fn.json_encode({
				model = "gpt-4o-mini",
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
						table.insert(messages, { role = "assistant", content = reply })
						vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "Assistant: " .. reply })
						cm.save(conv_name, messages)
					else
						vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "[Error fetching response]" })
					end
				end,
			})
		end)
	end, { buffer = chat_buf })
end

return M
