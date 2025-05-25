local Util = require("code-assist.util")
local Future = require("code-assist.future")
local Curl = require("plenary.curl")
local Parsing = require("code-assist.assistant.interface.parsing")
local BasicParser = require("code-assist.assistant.interface.basic-parser")

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
  vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- @type { create: (fun(class: Thread, prototype: ThreadPrototype): Future<Thread>),
--- load: (fun(class: Thread, id: string): Future<Thread>),
--- update: (fun(trd: Thread): Future<Thread>),
--- delete: (fun(trd: Thread): Future<boolean>),
--- list: (fun(class: Thread, max_entries: integer, after: Thread?, descending: boolean?)),
--- }
local Thread = {}

--- @param data table?
--- @return Thread?
local function decode_thread(class, data)
  if data == nil then
    return nil
  end
  assert(data.object == "thread")
  --- @diagnostic disable: missing-fields
  --- @type Thread
  local thread = {
    created_at = Parsing.try_get_number("created_at", "integer", data),
    id = Parsing.try_get("id", "string", data),
    metadata = Parsing.try_get_optional("metadata", "table", data) or {},
    tool_resources = BasicParser.parse_tool_resources(data),
  }
  setmetatable(thread, class)
  return thread
end

local function decode_thread_delete_response(data, thread_id)
  assert(Parsing.try_get("object", "string", data) == "thread.deleted")
  assert(Parsing.try_get("id", "string", data) == thread_id)
  return Parsing.try_get("deleted", "boolean", data) == true
end

function Thread.create(class, prototype)
  local payload = vim.fn.json_encode(prototype)
  local temp_file = Util.get_temp_path() .. "/thread-create.tmp.json"
  vim.fn.writefile(payload, temp_file)
  --- @type Future<Thread>
  local status = Future:new()
  Curl.post("https://api.openai.com/v1/threads", {
    body = temp_file,
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local thread = decode_thread(class, response.body)
      assert(thread)
      status:complete(thread)
    end,
  })
  return status
end

function Thread.load(class, id)
  --- @type Future<Thread?>
  local status = Future:new()
  Curl.get("https://api.openai.com/v1/threads/" .. id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local thread = decode_thread(class, response.body)
      status:complete(thread)
    end,
  })
  return status
end

function Thread.update(thread)
  --- @type Future<Thread>
  local status = Future:new()
  Curl.post("https://api.openai.com/v1/threads" .. thread.id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local new_thread = decode_thread(thread, response.body)
      assert(new_thread)
      status:complete(new_thread)
    end,
  })
  return status
end

function Thread.delete(thread)
  --- @type Future<boolean>
  local status = Future:new()
  Curl.delete("https://api.openai.com/v1/threads/" .. thread.id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local result = decode_thread_delete_response(response.body, thread.id)
      status:complete(result)
    end,
  })
  return status
end

return Thread
