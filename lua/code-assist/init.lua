-- Expose user commands and keymaps

require("code-assist.conversation-manager").setup()

vim.api.nvim_set_hl(0, "ChatUser", { fg = "#a3be8c", bold = true })
vim.api.nvim_set_hl(0, "ChatAssistant", { fg = "#88c0d0", bold = true })

require("code-assist.commands.chat").setup()

local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>af", "<cmd>Chat f<CR>", opts)
vim.keymap.set("n", "<leader>ah", "<cmd>Chat h<CR>", opts)
vim.keymap.set("n", "<leader>av", "<cmd>Chat v<CR>", opts)
vim.keymap.set("n", "<leader>anf", "<cmd>Chat n f<CR>", opts)
vim.keymap.set("n", "<leader>anh", "<cmd>Chat n h<CR>", opts)
vim.keymap.set("n", "<leader>anv", "<cmd>Chat n v<CR>", opts)
vim.keymap.set("n", "<leader>asf", "<cmd>Chat s f<CR>", opts)
vim.keymap.set("n", "<leader>ash", "<cmd>Chat s h<CR>", opts)
vim.keymap.set("n", "<leader>asv", "<cmd>Chat s v<CR>", opts)
