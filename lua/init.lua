-- Expose user commands and keymaps

require("code-assist.conversation-manager").setup()

-- New conversation
vim.api.nvim_create_user_command("ChatNew", function()
	local name, msgs = require("code-assist.conversation-manager").new_conversation()
	require("code-assist.chat-window").open(name, msgs)
end, {})

-- Select existing conversation
vim.api.nvim_create_user_command("ChatSelect", function()
	require("code-assist.ui").select_conversation()
end, {})

-- Alias :AIChat to selection, and <leader>a
vim.api.nvim_create_user_command("Chat", function()
	require("code-assist.ui").select_conversation()
end, {})
