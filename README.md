# code-assist.nvim

A plugin to interact with the openai API for Neovim

## TODO

- [ ] Move rest of chat window control into chat window:
  - [ ] Conversation Manager event handling
- [ ] Chat editing
- [ ] (Refatoring) Move keymaps from chat-window-control into chat-window
- [ ] Chat Window Title
- [ ] Multi Line Inputs
- [ ] Keymaps
  - [ ] help (?) for every window
  - [ ] Rename conversation from chat window
  - [ ] Delete conversation from chat window
  - [ ] Select conversation from chat window
  - [ ] Change chat window size in split mode
- [ ] Project Conversations
- [ ] Plugin opts
  - [ ] model
  - [ ] system message
  - [ ] color
- [ ] In visual mode, relay content to chat
  - [ ] opts for code-block types
- [ ] Adjustable filter for messages
  - [ ] Move filtering into chat window

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
