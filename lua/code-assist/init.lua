return {
	"ai-assistant/astro-openai-chat",
	lazy = false,
	config = function()
		local api_key = os.getenv("OPENAI_API_KEY")
		if not api_key then
			vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
			return
		end

		local chat_buf, chat_win
		local messages = {
			{ role = "system", content = "You are a helpful programming assistant." },
		}

		local function open_chat_window()
			if chat_win and vim.api.nvim_win_is_valid(chat_win) then
				vim.api.nvim_set_current_win(chat_win)
				return
			end

			local width = math.floor(vim.o.columns * 0.6)
			local height = math.floor(vim.o.lines * 0.6)
			local row = math.floor((vim.o.lines - height) / 2)
			local col = math.floor((vim.o.columns - width) / 2)

			chat_buf = vim.api.nvim_create_buf(false, true)
			chat_win = vim.api.nvim_open_win(chat_buf, true, {
				relative = "editor",
				width = width,
				height = height,
				row = row,
				col = col,
				style = "minimal",
				border = "rounded",
			})

			vim.bo[chat_buf].filetype = "markdown"
			vim.keymap.set("n", "q", function()
				vim.api.nvim_win_close(chat_win, true)
			end, { buffer = chat_buf })
			vim.keymap.set("n", "<CR>", function()
				vim.ui.input({ prompt = "You: " }, function(input)
					if input then
						table.insert(messages, { role = "user", content = input })
						vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "You: " .. input })

						local json = vim.fn.json_encode({
							model = "gpt-4",
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
							json,
						}, {
							stdout_buffered = true,
							on_stdout = function(_, data)
								local resp = table.concat(data, "")
								local ok, decoded = pcall(vim.fn.json_decode, resp)
								if ok and decoded and decoded.choices and decoded.choices[1] then
									local msg = decoded.choices[1].message.content
									table.insert(messages, { role = "assistant", content = msg })
									vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "Assistant: " .. msg })
								else
									vim.api.nvim_buf_set_lines(chat_buf, -1, -1, false, { "[Error fetching response]" })
								end
							end,
						})
					end
				end)
			end, { buffer = chat_buf })
		end

		-- Keymap: <leader>a opens the chat
		vim.keymap.set("n", "<leader>a", open_chat_window, { desc = "Open AI Chat" })

		vim.notify("AI Chat ready: <leader>a", vim.log.levels.INFO)
	end,
}
