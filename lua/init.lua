-- Expose user commands and keymaps

require("ai_chat.conversation_manager").setup()

-- New conversation
vim.api.nvim_create_user_command("AIChatNew", function()
	local name, msgs = require("ai_chat.conversation_manager").new_conversation()
	require("ai_chat.chat_window").open(name, msgs)
end, {})

-- Select existing conversation
vim.api.nvim_create_user_command("AIChatSelect", function()
	require("ai_chat.ui").select_conversation()
end, {})

-- Alias :AIChat to selection, and <leader>a
vim.api.nvim_create_user_command("AIChat", function()
	require("ai_chat.ui").select_conversation()
end, {})

vim.keymap.set("n", "<leader>a", "<cmd>AIChatSelect<CR>", { desc = "Open AI Chat" })
