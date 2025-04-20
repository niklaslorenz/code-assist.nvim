# code-assist.nvim

A plugin to interact with the openai API for Neovim

## Setup

Lazy:

```lua

{
  "niklaslorenz/code-assist.nvim",
  config = function()
    -- nothing needed here, plugin’s init.lua wires it up
  end,
  keys = {
    { "<leader>as", "<cmd>AIChatSelect<CR>", desc = "AI Chat: select conversation" },
    { "<leader>an", "<cmd>AIChatNew<CR>",    desc = "AI Chat: new conversation" },
  },
}
```
