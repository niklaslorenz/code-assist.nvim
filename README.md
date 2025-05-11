# code-assist.nvim

A plugin to interact with the openai API for Neovim

## TODO

Roadmap:

- [x] Refactor Chat window
  - [x] Message Tracking
- [x] Message Input Window
- [-] Project conversations
- [ ] Assistant basic threads
- [ ] tool calls
- [x] Refactor Select Window

Bucket List:

- [ ] Put selected context into its own channel
- [ ] Conversation length management
  - [ ] Conversation token length tracking
  - [ ] Make sure that the system message is not truncated
- [x] Define location for user issued requests to the conversation manager
  - > ui/interactions.lua
  - Handles global and window keymap actions
  - Ensures preconditions
  - Notifies user on error
- [x] Ensure compliance to the conversation manager preconditions
  - [x] Define all preconditions
  - [x] Ensure proper handling of results
- [x] Conversation sorting in selection screen
  - [x] keymap with o-<sort order key>
  - [x] plugin opt for default sorting order
- [x] Dynamic message filters
  - [x] Plugin opt for default filter
- [ ] implement a on_msg_delete event so the chat window does not have to redraw the conversation
  - needs message tracking
- [x] implement a chat completions request object
  - [x] put the streaming request into chat-completions and keep the interface.streaming.lua file
        for processing logic only
- [x] Response Streaming
- [-] Chat editing
  - Goals?
- [x] (Refatoring) Cleanup chat-window-control
- [x] Chat Window Title
- [x] Multi Line Inputs
- [-] Keymaps
  - [x] leader + a + b -> scroll to bottom
  - [x] Previous and next message start/end with \[c, \[C \]c \]C
    - needs message tracking
  - [x] Rename conversation from chat window
  - [x] Delete conversation from chat window
  - [x] Select conversation from chat window
  - [x] Change chat window size in split mode
  - [x] Change delete keymap as it is already used by the delete feature -> leads to delay
- [ ] Project Conversations
- [x] Plugin opts
  - [x] model
  - [x] system message
  - [x] color
- [x] In visual mode, relay content to chat
  - [x] opts for code-block types
- [x] Adjustable filter for messages
  - [x] Move filtering into chat window
- [ ] Conversation "Snippets" (see [./conversations-roadmap.md](./conversations-roadmap.md)):
  - Unnamed and unstructured conversations
  - Indexed by topics
  - Searchable via vector_stores
  - Link to each other
  - Whenever a new snippet is created, the context is automatically updated with content
    from snippets with similar topics

## BUGS

- Closing a window buffer externally will result in an invalid window state
- When renaming a convesation, last_conversation is not updated resulting in a new conversation being created when opened again after restart
- Chat window title is not updated when the active conversation is renamed
- The context selection is scuffed

## Setup

Lazy:

```lua
return {
  "niklaslorenz/code-assist.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {},
  events = { "VeryLazy" },
  branch = "dev",
}
```
