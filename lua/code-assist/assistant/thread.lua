local Interface = require("code-assist.assistant.interface.thread")
local MessageInterface = require("code-assist.assistant.interface.message")
local Message = require("code-assist.assistant.message")

--- @class ThreadPrototype
--- @field messages MessagePrototype[]?
--- @field metadata table<string, string>?
--- @field tool_resources AssistantToolResources?

--- @class Thread
--- @field created_at integer
--- @field id string
--- @field metadata table<string, string>
--- @field tool_resources AssistantToolResources?
--- @field create fun(trd: Thread, prototype: ThreadPrototype): Future<Thread>
--- @field load fun(trd: Thread, id: string): Future<Thread>
--- @field update fun(trd: Thread): Future<Thread>
--- @field delete fun(trd: Thread): Future<boolean>
--- @field messages Message[]
--- @field add_message fun(trd: Thread, prototype: MessagePrototype): Future<Message>
--- @field load_messages fun(trd: Thread): Future<Message[]>
--- @field list fun(trd: Thread, max_entries: integer, after: Thread?, ascending: boolean?): Future<Thread[]>
local Thread = {}
Thread.__index = Thread

function Thread:create(prototype)
	return Interface.create(self, prototype)
end

function Thread:load(id)
	return Interface.load(self, id)
end

function Thread:update()
	return Interface.update(self)
end

function Thread:delete()
	return Interface.delete(self)
end

function Thread:add_message(prototype)
	return MessageInterface.create(Message, self, prototype)
end

function Thread:load_messages()
	return MessageInterface.list(Message, self)
end

function Thread:list(max_entries, after, descending)
	return Interface.list(self, max_entries, after, descending)
end
