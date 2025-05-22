--- @meta

--- @alias ConversationItemClass "item"|"message"
--- @alias ConversationType "listed"|"unlisted"|"project"
--- @alias ConversationRole "user"|"assistant"|"system"
--- @alias ConversationChannel "assistant"|"user-direct"|"user-generated"|"user-context"|"system"
--- @alias ConversationSorting "newest"|"oldest"|"name"

--- @class MessageDelta
--- @field content string?

--- @class MessageExtensionEvent
--- @field message ConversationMessage
--- @field old_content string
--- @field delta string

--- @class ConversationSwitchEvent
--- @field conversation Conversation?

--- @class NewItemEvent
--- @field new_item ConversationItem

--- @class MessageExtendEvent
--- @field delta string

--- @class ItemDeletedEvent
--- @field deleted_item ConversationItem
--- @field deleted_index integer

--- @class ConversationManagerStatus
--- @field complete boolean
--- @field streamed boolean
--- @field items ConversationItem[]
