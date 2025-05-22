local Util = require("code-assist.util")
local Future = require("code-assist.future")
local Curl = require("plenary.curl")
local Parsing = require("code-assist.assistant.interface.parsing")
local BasicParser = require("code-assist.assistant.interface.basic-parser")

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key then
  vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
end

--- @type {create: (fun(class: Message, thread: Thread, prototype: MessagePrototype): Future<Message>),
--- load: (fun(class: Message, thread: Thread, id: string): Future<Message?>),
--- update: (fun(msg: Message): Future<Message>),
--- delete: (fun(msg: Message): Future<boolean>),
--- list: (fun(class: Message, thread: Thread, max_entries: integer, after: Message, descending: boolean): Future<Message[]>),
--- }
local Message = {}

--- @param class Message
--- @param thread Thread
--- @param data table?
--- @return Message?
local function decode_message(class, thread, data)
  if data == nil then
    return nil
  end
  assert(Parsing.try_get("type", "string", data) == "message")
  local thread_id = Parsing.try_get("thread_id", "string", data)
  assert(thread_id == thread.id)
  --- @diagnostic disable: missing-fields
  --- @type Message
  local message = {
    assistant_id = Parsing.try_get_optional("assistant_id", "string", data),
    attachments = Parsing.try_parse_optional_array(
      "attachments",
      "table",
      data,
      BasicParser.decode_message_attachment,
      true
    ) or {},
    completed_at = Parsing.try_get_optional_number("completed_at", "integer", data),
    content = Parsing.try_parse_array("content", "table", data, BasicParser.decode_message_content, true),
    created_at = Parsing.try_get_number("created_at", "integer", data),
    id = Parsing.try_get("id", "string", data),
    incomplete_at = Parsing.try_get_optional_numnber("incomplete_at", "integer", data),
    incomplete_reason = Parsing.try_get_optional("incomplete_reason", "string", data),
    metadata = Parsing.try_get_optional("metadata", "table", data) or {},
    role = Parsing.try_get("role", "string", data),
    run_id = Parsing.try_get("run_id", "string", data),
    status = Parsing.try_get("status", "string", data),
    thread = thread,
  }
  setmetatable(message, class)
  return message
end

local function decode_message_delete_response(data, message_id)
  assert(Parsing.try_get("object", "string", data) == "thread.message.deleted")
  assert(Parsing.try_get("id", "string", data) == message_id)
  return Parsing.try_get("deleted", "boolean", data)
end

function Message.create(class, thread, prototype)
  local payload = vim.fn.json_encode(prototype)
  local temp_file = Util.get_temp_path() .. "/message-create.tmp.json"
  vim.fn.writefile(payload, temp_file)
  --- @type Future<Message>
  local status = Future:new()
  Curl.post("https://api.openai.com/v1/threads/" .. thread.id .. "/messages", {
    body = temp_file,
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local message = decode_message(class, thread, response.body)
      assert(message)
      status:complete(message)
    end,
  })
  return status
end

function Message.load(class, thread, id)
  --- @type Future<Message?>
  local status = Future:new()
  Curl.get("https://api.openai.com/v1/threads/" .. thread.id .. "/messages/" .. id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local message = decode_message(class, thread, response.body)
      status:complete(message)
    end,
  })
  return status
end

function Message.update(message)
  --- @type Future<Message>
  local status = Future:new()
  Curl.post("https://api.openai.com/v1/threads/" .. message.thread.id .. "/messages/" .. message.id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local result = decode_message(message, message.thread, response.body)
      assert(result)
      status:complete(result)
    end,
  })
  return status
end

function Message.delete(message)
  --- @type Future<boolean>
  local status = Future:new()
  Curl.delete("https://api.openai.com/v1/threads/" .. message.thread.id .. "/messages/" .. message.id, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      local result = decode_message_delete_response(response.body, message.id)
      status:complete(result)
    end,
  })
  return status
end

function Message.list(class, thread, max_entries, after, descending)
  local request = {
    after = after,
    limit = max_entries,
    order = descending and "desc" or "asc",
    run_id = 
  }
  local payload = vim.fn.json_encode(request)
  --- @type Future<Thread[]>
  local status = Future:new()
  Curl.get("https://api.openai.com/v1/threads/" .. thread.id .. "/messages/", {
    body = payload,
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
      ["OpenAI-Beta"] = "assistants=v2",
    },
    raw = { "s" },
    callback = function(response)
      assert(Parsing.try_get("object", "string", response.body) == "list")
      local list = Parsing.try_parse_array("data", "string", response.body, function(data)
        return decode_message(class, thread, data)
      end, true)
    end,
  })
  return status
end

return Message
