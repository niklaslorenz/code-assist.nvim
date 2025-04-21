local M = {}
local fn = vim.fn
local data_path = fn.stdpath("data") .. "/code-assist"
local conv_path = data_path .. "/conversations"
local last_conv_file = data_path .. "/last_conv"

---@alias Role "user"|"assistant"|"system"

---@class Message
---@field role Role
---@field content string

---@class Conversation
---@field name string
---@field messages Message[]

---@alias ConversationUpdateEvent "append"|"switch"

-- Current conversation state (nil if none yet)
---@type Conversation|nil
local current_conversation = nil

--- Subscriber callbacks receive event, name, and messages
---@type fun(event: ConversationUpdateEvent, name: string, messages: Message[])[]
local subscribers = {}

---Ensure that a directory exists.
---@param path string
local function ensure_dir(path)
	if fn.isdirectory(path) == 0 then
		fn.mkdir(path, "p")
	end
end

---Notify all subscribers with updated conversation data.
---@param event ConversationUpdateEvent
local function notify(event)
	if not current_conversation then
		return
	end
	for _, cb in ipairs(subscribers) do
		-- safe call with event, name, messages
		pcall(cb, event, current_conversation.name, current_conversation.messages)
	end
end

---Subscribe to conversation updates.
---@param callback fun(event: ConversationUpdateEvent, name: string, messages: Message[])
function M.subscribe(callback)
	table.insert(subscribers, callback)
end

---Unsubscribe from conversation updates.
---@param callback fun(event: ConversationUpdateEvent, name: string, messages: Message[])
function M.unsubscribe(callback)
	for i, f in ipairs(subscribers) do
		if f == callback then
			table.remove(subscribers, i)
			return
		end
	end
end

---Initialize manager and load last conversation if available.
function M.setup()
	ensure_dir(data_path)
	ensure_dir(conv_path)
	M.load_last_conversation()
end

---Save the last conversation name to disk.
---@param name string
local function save_last(name)
	fn.writefile({ name }, last_conv_file)
end

---List all saved conversation names.
---@return string[]
function M.list_conversations()
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
function M.load_conversation(name)
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 1 then
		local content = fn.readfile(fname)
		local ok, data = pcall(fn.json_decode, table.concat(content, "\n"))
		if ok and data.messages then
			current_conversation = { name = name, messages = data.messages }
			save_last(name)
			notify("switch")
			return true
		end
	end
	return false
end

---Load the last conversation (if exists).
---@return boolean success
function M.load_last_conversation()
	if fn.filereadable(last_conv_file) == 1 then
		local lines = fn.readfile(last_conv_file)
		local name = lines[1]
		return M.load_conversation(name)
	end
	return false
end

---Save the current conversation to disk.
function M.save_current_conversation()
	if not current_conversation then
		return
	end
	local fname = conv_path .. "/" .. current_conversation.name .. ".json"
	fn.writefile({ fn.json_encode({ messages = current_conversation.messages }) }, fname)
	save_last(current_conversation.name)
end

---Create a new conversation and notify subscribers.
---@return string name, Message[] messages
function M.new_conversation()
	local name = os.date("%Y-%m-%d_%H-%M-%S")
	assert(type(name) == "string") -- needed for type checker
	local messages = { { role = "system", content = "You are a helpful programming assistant." } }
	current_conversation = { name = name, messages = messages }
	M.save_current_conversation()
	notify("switch")
	return name, messages
end

---Load last or create new conversation.
---@return string name, Message[] messages
function M.load_or_new()
	if M.load_last_conversation() and current_conversation then
		return current_conversation.name, current_conversation.messages
	end
	return M.new_conversation()
end

---Append a message to the current conversation, save, and notify.
---@param message Message
---@param name string? Optional conversation name to verify
---@return boolean success, string? reason
function M.append_message(message, name)
	if not current_conversation then
		return false, "no current conversation"
	end
	if name and name ~= current_conversation.name then
		return false, "conversation mismatch"
	end
	table.insert(current_conversation.messages, message)
	M.save_current_conversation()
	notify("append")
	return true
end

---Get the current conversation.
---@return Conversation|nil
function M.get_current_conversation()
	return current_conversation
end

return M
