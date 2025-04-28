# code-assist.nvim

A plugin to interact with the openai API for Neovim

## TODO

- [x] Define location for user issued requests to the conversation manager
  - > ui/interactions.lua
  - Handles global and window keymap actions
  - Ensures preconditions
  - Notifies user on error
- [x] Ensure compliance to the conversation manager preconditions
  - [x] Define all preconditions
  - [x] Ensure proper handling of results
- [ ] Conversation sorting in selection screen
  - [ ] keymap with o-<sort order key>
  - [ ] plugin opt for default sorting order
- [ ] Dynamic message filters
  - [ ] Plugin opt for default filter
- [ ] implement a on_msg_delete event so the chat window does not have to redraw the conversation
  - needs message tracking
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
  - [ ] help (?) for every window / keymap descriptions
  - [x] Rename conversation from chat window
  - [x] Delete conversation from chat window
  - [x] Select conversation from chat window
  - [ ] Change chat window size in split mode
  - [x] Change delete keymap as it is already used by the delete feature -> leads to delay
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
- When conversations get too long, the curl command that issues the response request cannot be executed any more as the entire conversation is currently relayed via a parameter

## Setup

Lazy:

```lua

{
  "niklaslorenz/code-assist.nvim",
  opts = {},
  lazy = false,
  branch = "dev",
}
```
