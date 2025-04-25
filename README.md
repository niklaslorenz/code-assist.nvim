# code-assist.nvim

A plugin to interact with the openai API for Neovim

## TODO

- [ ] implement a chat completions request object
  - [ ] put the streaming request into chat-completions and keep the interface.streaming.lua file
        for processing logic only
- [ ] switch chat command argument positions (especially for keymaps)
  - allows opening or selecting without specifying the orientation again
- [ ] Implement futures and async safe queues for keymaps and responses
- [ ] Response Streaming
- [ ] Move rest of chat window control into chat window:
  - [ ] Conversation Manager event handling
- [ ] Chat editing
- [ ] (Refatoring) Move keymaps from chat-window-control into chat-window
- [ ] Chat Window Title
- [ ] Multi Line Inputs
- [o] Keymaps
  - [ ] Previous and next message start/end with \[c, \[C \]c \]C
  - [ ] help (?) for every window
  - [x] Rename conversation from chat window
  - [x] Delete conversation from chat window
  - [ ] Select conversation from chat window
  - [ ] Change chat window size in split mode
  - [ ] Change delete keymap as it is already used by the delete feature -> leads to delay
- [ ] Project Conversations
- [ ] Plugin opts
  - [ ] model
  - [ ] system message
  - [ ] color
- [ ] In visual mode, relay content to chat
  - [ ] opts for code-block types
- [ ] Adjustable filter for messages
  - [ ] Move filtering into chat window
- [ ] Add Conversation manager event for name change of current conversation
  - [ ] Update window title accordingly
- [ ] Conversation "Snippets":
  - Unnamed and unstructured conversations
  - Indexed by topics
  - Searchable via vector_stores
  - Link to each other
  - Whenever a new snippet is created, the context is automatically updated with content
    from snippets with similar topics

## BUGS

- When renaming a convesation, last_conversation is not updated resulting in a new conversation being created when opened again after restart

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
