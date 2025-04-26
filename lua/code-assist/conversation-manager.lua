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

--- @class MessageDelta
--- @field content string

---@class Conversation
---@field name string
---@field messages Message[]

--- @class ConversationSwitchEvent
--- @field new_messages Message[]
--- @field name string

--- @class NewMessageEvent
--- @field new_message Message

--- @class MessageExtendEvent
--- @field delta string

--- Current conversation state (nil if none yet)
--- @type Conversation|nil
local current_conversation = nil

--- @type ChatCompletionResponseStatus | nil
local current_response = nil

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
	assert(ConversationManager.is_ready())
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) ~= 0 then
		local content = fn.readfile(fname)
		local ok, data = pcall(fn.json_decode, table.concat(content, "\n"))
		if ok and data.messages then
			current_conversation = { name = name, messages = data.messages }
			save_last(name)
			ConversationManager.on_conversation_switch:dispatch({
				name = current_conversation.name,
				new_messages = current_conversation.messages,
			})
			return true
		end
	end
	return false
end

---Load the last conversation (if exists).
---@return boolean success
function ConversationManager.load_last_conversation()
	assert(ConversationManager.is_ready())
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
	assert(ConversationManager.is_ready())
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 0 then
		return false
	end
	local success = fn.delete(fname) == 0
	if success and current_conversation and current_conversation.name == name then
		current_conversation = nil
		ConversationManager.on_conversation_switch:dispatch({ name = name, new_messages = {} })
	end
	return success
end

--- @return boolean success
function ConversationManager.rename_conversation(name, new_name)
	assert(ConversationManager.is_ready())
	local fname = conv_path .. "/" .. name .. ".json"
	if fn.filereadable(fname) == 0 then
		return false
	end
	local new_fname = conv_path .. "/" .. new_name .. ".json"
	if vim.fn.filereadable(new_fname) ~= 0 then
		return false
	end
	local success = fn.rename(fname, new_fname) == 0
	if success and current_conversation and current_conversation.name == name then
		current_conversation.name = new_name
	end
	return success
end

---Save the current conversation to disk.
function ConversationManager.save_current_conversation()
	assert(current_conversation)
	local fname = conv_path .. "/" .. current_conversation.name .. ".json"
	fn.writefile({ fn.json_encode({ messages = current_conversation.messages }) }, fname)
end

---Create a new conversation and notify subscribers.
---@param name string?
function ConversationManager.new_conversation(name)
	assert(ConversationManager.is_ready())
	name = name or os.date("%Y-%m-%d_%H-%M-%S") --[[@as string]]
	local messages = { { role = "system", content = initial_system_message } }
	current_conversation = { name = name, messages = messages }
	ConversationManager.save_current_conversation()
	save_last(name)
	ConversationManager.on_conversation_switch:dispatch({
		name = name,
		new_messages = current_conversation.messages,
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
function ConversationManager.add_message(message, name)
	if not current_conversation then
		return false, "no current conversation"
	end
	if name and name ~= current_conversation.name then
		return false, "conversation mismatch"
	end
	table.insert(current_conversation.messages, message)
	ConversationManager.save_current_conversation()
	ConversationManager.on_new_message:dispatch({ new_message = message })
	return true
end

--- Extend the last message of the current conversation.
--- @param msg_delta string
function ConversationManager.extend_last_message(msg_delta, conversation_name)
	if not current_conversation then
		return false, "no current conversation"
	end
	if conversation_name and current_conversation.name ~= conversation_name then
		return false, "conversation mismatch"
	end
	local last_msg = current_conversation.messages[#current_conversation.messages]
	if not last_msg then
		return false, "no chat messages"
	end
	if last_msg.role == "system" then
		return false, "cannot extend system messages"
	end
	last_msg.content = last_msg.content .. msg_delta
	ConversationManager.on_message_extend:dispatch({
		delta = msg_delta,
	})
end

--- Delete the last message of the current conversation.
--- # Preconditions:
--- - `ConversationManager.is_ready()`
--- - `ConversationManager.current_conversation ~= nil`
function ConversationManager.delete_last_message()
	assert(current_conversation)
	assert(ConversationManager.is_ready())
	local message_count = #current_conversation.messages
	if message_count == 0 then
		return
	end
	table.remove(current_conversation.messages, message_count)
	ConversationManager.on_conversation_switch:dispatch({
		name = current_conversation.name,
		new_messages = current_conversation.messages,
	})
end

--- Get the current conversation.
--- @nodiscard
--- @return Conversation|nil
function ConversationManager.get_current_conversation()
	return current_conversation
end

--- Get the current response status.
--- @nodiscard
--- @return ChatCompletionResponseStatus | nil
function ConversationManager.get_status()
	return current_response
end

--- @nodiscard
function ConversationManager.has_conversation()
	return current_conversation ~= nil
end

--- Determine if the conversation manager is ready to generate a new response.
--- @nodiscard
--- @return boolean ready
function ConversationManager.is_ready()
	if not current_response then
		return true
	end
	if not current_response.complete then
		print("not ready. Status")
		print(current_response)
		return false
	end
	return true
end

--- Generate a response for the current conversation.
function ConversationManager.generate_response()
	assert(current_conversation)
	assert(ConversationManager.is_ready())
	local response_status = ChatCompletions.post_request(model, current_conversation.messages, function(message)
		ConversationManager.add_message(message)
	end)
	current_response = response_status
end

--- Generate a response and stream the result to the current conversation.
function ConversationManager.generate_streaming_response()
	assert(current_conversation)
	assert(ConversationManager.is_ready())
	local response_status = ChatCompletions.post_streaming_request(
		model,
		current_conversation.messages,
		function(_, chunks)
			local current_delta_msg = nil
			for _, chunk in pairs(chunks) do
				if chunk.choices[1] then
					local delta = chunk.choices[1].delta
					if not delta.role then
						if delta.content then
							if current_delta_msg then
								current_delta_msg = current_delta_msg .. delta.content
							else
								current_delta_msg = delta.content
							end
						end
					else
						if current_delta_msg then
							ConversationManager.extend_last_message(current_delta_msg)
							current_delta_msg = nil
						end
						ConversationManager.add_message({
							role = delta.role,
							content = delta.content or "",
						})
					end
				end
			end
			if current_delta_msg then
				ConversationManager.extend_last_message(current_delta_msg)
			end
		end,
		function(_)
			ConversationManager.save_current_conversation()
		end
	)
	current_response = response_status
end

--- @type EventDispatcher<MessageExtendEvent>
ConversationManager.on_message_extend = EventDispatcher.new()
--- @type EventDispatcher<NewMessageEvent>
ConversationManager.on_new_message = EventDispatcher.new()
--- @type EventDispatcher<ConversationSwitchEvent>
ConversationManager.on_conversation_switch = EventDispatcher.new()

return ConversationManager
