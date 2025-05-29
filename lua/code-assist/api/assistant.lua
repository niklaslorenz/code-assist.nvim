local Parser = require("code-assist.api.parser.assistant")

--- @class Assistant
--- @field created_at integer
--- @field description string?
--- @field id string
--- @field instructions string?
--- @field metadata table<string, string>
--- @field model string
--- @field name string?
--- @field response_format { type: "text"} | { type: "json_schema", json_schema: string }?
--- @field temperature number?
--- @field tool_resources AssistantToolResources?
--- @field tools AssistantTool[]
--- @field top_p number?
--- @field load fun(ast: Assistant, id: string): Future<Assistant?>
--- @field create fun(ast: Assistant, prototype: AssistantPrototype): Future<Assistant>
--- @field delete fun(ast: Assistant): Future<boolean>
--- @field list fun(ast: Assistant, opts: AssistantListOpts): Future<Assistant[]>
local Assistant = {}
Assistant.__index = Assistant

function Assistant:load(id)
	return Parser.load(self, id)
end

function Assistant:create(prototype)
	return Parser.create(self, prototype)
end

function Assistant:delete()
	return Parser.delete(self)
end

function Assistant:list(opts)
	return Parser.list(self, opts)
end

return Assistant
