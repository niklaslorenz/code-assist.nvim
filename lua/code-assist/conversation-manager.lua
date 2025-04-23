local ConversationManager = {}

local EventDispatcher = require("code-assist.event-dispatcher")
local ChatCompletions = require("code-assist.assistant.chat-completions")

local fn = vim.fn
local data_path = fn.stdpath("data") .. "/code-assist"
local conv_path = data_path .. "/conversations"
local last_conv_file = data_path .. "/last_conv"

--- The model name to use for responses
--- @type string
local model = "gpt-4o-mini"

--- The system message that new conversations are initialized with.
--- @type string
local initial_system_message = "You are a helpful programming assistant."

---@alias Role "user"|"assistant"|"system"

---@class Message
---@field role Role
---@field content string

---@class Conversation
---@field name string
---@field messages Message[]

---@class ConversationUpdateEvent
---@field operation "append"|"switch"
---@field messages Message[]

-- Current conversation state (nil if none yet)
---@type Conversation|nil
local current_conversation = nil

---Ensure that a directory exists.
---@param path string
local function ensure_dir(path)
	if fn.isdirectory(path) == 0 then
		fn.mkdir(path, "p")
	end
end

---Save the last conversation name to disk.
---@param name string
local function save_last(name)
	fn.writefile({ name }, last_conv_file)
end

---Initialize manager and load last conversation if available.
function ConversationManager.setup()
	ensure_dir(data_path)
	ensure_dir(conv_path)
end

---List all saved conversation names.
---@return string[]
function ConversationManager.list_conversations()
	local files = fn.readdir(conv_path)
	local convs = {}
	for _, file in ipairs(files) do
		if file:match("%.json$") then
			table.insert(convs, file:sub(1, -6))
		end
	end
	table.sort(convs)
	return convs
end

---Load a saved conversation and notify subscribers.
---@param name string
---@return boolean success
function ConversationManager.load_conversation(name)
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) ~= 0 then
		local content = fn.readfile(fname)
		local ok, data = pcall(fn.json_decode, table.concat(content, "\n"))
		if ok and data.messages then
			current_conversation = { name = name, messages = data.messages }
			save_last(name)
			ConversationManager.on_conversation_update:dispatch({
				operation = "switch",
				messages = current_conversation.messages,
			})
			return true
		end
	end
	return false
end

---Load the last conversation (if exists).
---@return boolean success
function ConversationManager.load_last_conversation()
	if fn.filereadable(last_conv_file) ~= 0 then
		local lines = fn.readfile(last_conv_file)
		local name = lines[1]
		if current_conversation and current_conversation.name == name then
			return true
		end
		return ConversationManager.load_conversation(name)
	end
	return false
end

--- @return boolean success
function ConversationManager.delete_conversation(name)
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 0 then
		return false
	end
	return fn.delete(fname) == 0
end

--- @return boolean success
function ConversationManager.rename_conversation(name, new_name)
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 0 then
		return false
	end
	local new_fname = conv_path .. "/" .. new_name .. ".json"
	if vim.fn.filereadable(new_fname) ~= 0 then
		return false
	end
	return fn.rename(fname, new_fname) == 0
end

---Save the current conversation to disk.
function ConversationManager.save_current_conversation()
	assert(current_conversation)
	local fname = conv_path .. "/" .. current_conversation.name .. ".json"
	fn.writefile({ fn.json_encode({ messages = current_conversation.messages }) }, fname)
end

---Create a new conversation and notify subscribers.
function ConversationManager.new_conversation()
	local name = os.date("%Y-%m-%d_%H-%M-%S")
	assert(type(name) == "string") -- needed for type checker
	local messages = { { role = "system", content = initial_system_message } }
	current_conversation = { name = name, messages = messages }
	ConversationManager.save_current_conversation()
	save_last(name)
	ConversationManager.on_conversation_update:dispatch({
		operation = "switch",
		messages = current_conversation.messages,
	})
end

---Load last or create new conversation.
--- @return boolean loaded
function ConversationManager.load_last_or_create_new()
	if not ConversationManager.load_last_conversation() then
		ConversationManager.new_conversation()
		return false
	end
	return true
end

---Append a message to the current conversation, save, and notify.
---@param message Message
---@param name string? Optional conversation name to verify
---@return boolean success, string? reason
function ConversationManager.append_message(message, name)
	if not current_conversation then
		return false, "no current conversation"
	end
	if name and name ~= current_conversation.name then
		return false, "conversation mismatch"
	end
	table.insert(current_conversation.messages, message)
	ConversationManager.save_current_conversation()
	ConversationManager.on_conversation_update:dispatch({ operation = "append", messages = { message } })
	return true
end

---Get the current conversation.
---@return Conversation|nil
function ConversationManager.get_current_conversation()
	return current_conversation
end

--- Generate a response for the current conversation.
function ConversationManager.generate_response()
	assert(current_conversation)
	local conversation_name = current_conversation.name
	ChatCompletions.create_response(model, current_conversation.messages, function(response)
		if response then
			ConversationManager.append_message(response, conversation_name)
		else
			ConversationManager.append_message({ role = "assistant", content = "[Error fetching response]" })
		end
	end)
end

--- @type EventDispatcher<ConversationUpdateEvent>
ConversationManager.on_conversation_update = EventDispatcher.new()

return ConversationManager
