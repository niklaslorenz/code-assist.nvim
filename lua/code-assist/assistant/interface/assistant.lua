local Future = require("code-assist.future")
local Curl = require("plenary.curl")
local Util = require("code-assist.util")
local Parsing = require("code-assist.assistant.interface.parsing")
local BasicParser = require("code-assist.assistant.interface.basic-parser")

--- @type {
--- create: (fun(class: Assistant, prototype: AssistantPrototype): Future<Assistant>),
--- load: (fun(class: Assistant, assistant_id: string): Future<Assistant>),
--- delete: (fun(id: string): Future<boolean>),
--- list: (fun(class: Message, opts: AssistantListOpts): Future<Assistant[]>),
--- }

local Assistant = {}

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
	vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- @param data table|string?
--- @return { type: "text" } | { type: "json_schema", json_schema: string}?
local function parse_response_format(data)
	if data == nil then
		return nil
	end
	if type(data) == "string" then
		if data == "auto" then
			return nil
		else
			error("Unknown response format literal: " .. data)
		end
	end
	local type = Parsing.try_get("type", "string", data)
	if type == "text" then
		return { type = "text" }
	elseif type == "json_schema" then
		return {
			type = "json_schema",
			json_schema = Parsing.try_get("json_schema", "string", data),
		}
	else
		error("Unknown response format: " .. type)
	end
end

--- @param data table?
--- @return AssistantTool?
local function parse_tool(data)
	if data == nil then
		return nil
	end
	--- @type "code_interpreter"|"file_search"|"function"
	local type = Parsing.try_get("type", "string", data)
	if type == "code_interpreter" then
		--- @type AssistantCodeInterpreter
		local interpreter = {
			type = "code_interpreter",
		}
		return interpreter
	elseif type == "file_search" then
		error("File search tool is not implemented yet.")
	elseif type == "function" then
		--- @type AssistantFunction
		local fun = {
			type = "function",
			description = Parsing.try_get("description", "string", data),
			name = Parsing.try_get("name", "string", data),
			parameters = Parsing.try_get("name", "string", data),
			strict = Parsing.try_get("name", "boolean", data),
		}
		return fun
	end
end

--- @param class Assistant
--- @param data table?
--- @return Assistant?
local function decode_assistant(class, data)
	if data == nil then
		return nil
	end
	assert(data.object == "assistant")
	--- @diagnostic disable: missing-fields
	--- @type Assistant
	local assistant = {
		created_at = Parsing.try_get_number("created_at", "integer", data),
		description = Parsing.try_get_optional("description", "string", data),
		id = Parsing.try_get("id", "string", data),
		instructions = Parsing.try_get_optional("instructions", "string", data),
		metadata = Parsing.try_get_optional("metadata", "table", data) or {},
		model = Parsing.try_get("model", "string", data),
		name = Parsing.try_get_optional("name", "string", data),
		response_format = Parsing.try_parse_optional_object("response_format", data, parse_response_format),
		temperature = Parsing.try_get_number("temperature", "float", data),
		tool_resources = Parsing.try_parse_optional_object("tool_resources", data, BasicParser.parse_tool_resources),
		tools = Parsing.try_parse_optional_array("tools", "table", data, parse_tool, true) or {},
		top_p = Parsing.try_get_optional_number("top_p", "float", data),
	}
	setmetatable(assistant, class)
	return assistant
end

--- @param data table
--- @param assistant_id string
--- @return boolean
local function decode_assistant_delete_response(data, assistant_id)
	assert(Parsing.try_get("object", "string", data) == "assistant.deleted")
	assert(Parsing.try_get("id", "string", data) == assistant_id)
	return Parsing.try_get("deleted", "boolean", data)
end

--- @param class Assistant
--- @param prototype AssistantPrototype
--- @return Future<Assistant>
function Assistant.create(class, prototype)
	local payload = vim.fn.json_encode(prototype)
	local temp_file = Util.get_temp_path() .. "/assistant-create.tmp.json"
	vim.fn.writefile({ payload }, temp_file)
	--- @type Future<Assistant>
	local status = Future:new()
	Curl.post("https://api.openai.com/v1/assistants", {
		body = temp_file,
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
			["OpenAI-Beta"] = "assistants=v2",
		},
		raw = { "s" },
		callback = function(response)
			if response.status ~= 200 then
				vim.notify("Http response error: " .. response.status, vim.log.levels.ERROR)
				return
			end
			vim.schedule(function()
				local assistant = decode_assistant(class, response.body)
				assert(assistant)
				status:complete(assistant)
			end)
		end,
	})
	return status
end

--- @param class Assistant
--- @param assistant_id string
function Assistant.load(class, assistant_id)
	--- @type Future<Assistant?>
	local status = Future:new()
	Curl.get("https://api.openai.com/v1/assistants/" .. assistant_id, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
			["OpenAI-Beta"] = "assistants=v2",
		},
		raw = { "s" },
		callback = function(response)
			local assistant = decode_assistant(class, response.body)
			status:complete(assistant)
		end,
	})
	return status
end

--- @param assistant Assistant
function Assistant.delete(assistant)
	--- @type Future<boolean>
	local status = Future:new()
	status.object = false
	Curl.delete("https://api.openai.com/v1/assistants/" .. assistant.id, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
			["OpenAI-Beta"] = "assistants=v2",
		},
		raw = { "s" },
		callback = function(response)
			local result = decode_assistant_delete_response(response.body, assistant.id)
			status.on_complete(result)
		end,
	})
	return status
end

function Assistant.list(class, opts)
	local payload = vim.fn.json_encode(opts)
	--- @type Future<Assistant[]>
	local status = Future:new()
	Curl.get("https://api.openai.com/v1/assistants", {
		body = { payload },
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
			["OpenAI-Beta"] = "assistants=v2",
		},
		raw = { "s" },
		callback = function(response)
			assert(Parsing.try_get("object", "string", response.body))
			local result = Parsing.try_parse_array("data", "table", response.body, function(response_data)
				return decode_assistant(class, response_data)
			end, true)
			status:complete(result)
		end,
	})
	return status
end

return Assistant
