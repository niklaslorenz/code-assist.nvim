# code-assist.nvim

A plugin to interact with the openai API for Neovim

## TODO

- [ ] Define location for user issued requests to the conversation manager
  - Handles global and window keymap actions
  - Ensures preconditions
  - Notifies user on error
- [ ] Ensure compliance to the conversation manager preconditions
  - [ ] Define all preconditions
  - [ ] Define result scenarios
  - [ ] Ensure proper handling of results
- [ ] Conversation sorting in selection screen
  - [ ] keymap with o-<sort order key>
  - [ ] plugin opt for default sorting order
- [ ] Dynamic message filters
  - [ ] Plugin opt for default filter
- [ ] implement remaining keymap commands in commands.chat
- [ ] implement a on_msg_delete event so the chat window does not have to redraw the conversation
  - [ ] needs message tracking
- [x] implement a chat completions request object
  - [x] put the streaming request into chat-completions and keep the interface.streaming.lua file
        for processing logic only
- [x] Response Streaming
- [-] Chat editing
  - Goals?
- [ ] (Refatoring) Cleanup chat-window-control
- [ ] Chat Window Title
- [ ] Multi Line Inputs
- [-] Keymaps
  - [x] leader + a + b -> scroll to bottom
  - [ ] Previous and next message start/end with \[c, \[C \]c \]C
    - needs message tracking
  - [ ] help (?) for every window
  - [x] Rename conversation from chat window
  - [x] Delete conversation from chat window
  - [ ] Select conversation from chat window
  - [ ] Change chat window size in split mode
  - [ ] Change delete keymap as it is already used by the delete feature -> leads to delay
- [ ] Project Conversations
- [x] Plugin opts
  - [x] model
  - [x] system message
  - [x] color
- [ ] In visual mode, relay content to chat
  - [ ] opts for code-block types
- [ ] Adjustable filter for messages
  - [ ] Move filtering into chat window
- [ ] Window Titles
- [ ] Add Conversation manager event for name change of current conversation
  - [ ] Update window title accordingly
- [ ] Conversation "Snippets" (see [./conversations-roadmap.md](./conversations-roadmap.md)):
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
