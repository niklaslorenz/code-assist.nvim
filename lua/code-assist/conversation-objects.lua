--- @meta

--- @alias ConversationType "listed"|"unlisted"|"project"

---@alias ConversationRole "user"|"assistant"|"system"

---@class Message
---@field role ConversationRole
---@field content string?

--- @class Conversation
--- @field type ConversationType
--- @field name string
--- @field messages Message[]

--- @class MessageDelta
--- @field content string?
