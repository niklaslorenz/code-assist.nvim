local Interface = require("code-assist.assistant.interface.message")
--- @class Message
--- @field assistant_id string?
--- @field attachments MessageAttachment[]
--- @field completed_at integer?
--- @field content MessageContent[]
--- @field created_at integer
--- @field id string
--- @field incomplete_at integer?
--- @field incomplete_reason string?
--- @field metadata table<string, string>
--- @field role "user"|"assistant"
--- @field run_id string?
--- @field status "in_progress" | "incomplete" | "completed"
--- @field thread Thread
--- @field create fun(msg: Message, prototype: MessagePrototype): Future<Message>
--- @field load fun(msg: Message, id: string): Future<Message?>
--- @field update fun(msg: Message): Future<Message>
--- @field delete fun(msg: Message): Future<boolean>
local Message = {}
Message.__index = Message

function Message:load(id)
  return Interface.load(self, id)
end

function Message:update()
  return Interface.update(self)
end

function Message:delete()
  return Interface.delete(self)
end
