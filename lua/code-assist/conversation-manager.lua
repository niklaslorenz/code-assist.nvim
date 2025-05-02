local ConversationManager = {}

local EventDispatcher = require("code-assist.event-dispatcher")
local ChatCompletions = require("code-assist.assistant.chat-completions")
local PluginOptions = require("code-assist.options")

local data_path = PluginOptions.data_path
local conv_path = data_path .. "/conversations"
local last_conv_file = data_path .. "/last_conv"
local model = PluginOptions.model
local initial_system_message = PluginOptions.system_message

--- @alias ConversationSorting "first"|"last"|"name"

--- @class ConversationSwitchEvent
--- @field conversation Conversation?

--- @class NewMessageEvent
--- @field new_message Message

--- @class MessageExtendEvent
--- @field delta string

--- Current conversation state (nil if none yet)
--- @type Conversation|nil
local current_conversation = nil

--- @type ChatCompletionResponseStatus | nil
local current_response = nil

--- Ensure that a directory exists.
--- @param path string
local function ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

--- Save the last conversation name to disk.
--- @param name string
local function save_last(name)
	vim.fn.writefile({ name }, last_conv_file)
end

---Initialize manager and load last conversation if available.
function ConversationManager.setup()
	ensure_dir(data_path)
	ensure_dir(conv_path)
end

--- List all saved conversation names.
--- @nodiscard
--- @param sorting ConversationSorting?
--- @return string[]
function ConversationManager.list_conversations(sorting)
	sorting = sorting or "last"
	local files = vim.fn.readdir(conv_path)
	local convs = {}

	for _, file in ipairs(files) do
		if file:match("%.json$") then
			local name = file:sub(1, -6)                         -- remove the .json extension
			local mtime = vim.fn.getftime(conv_path .. "/" .. file) -- get the modification time
			table.insert(convs, { name = name, mtime = mtime })
		end
	end

	-- Sort by modification time
	if sorting == "first" then
		table.sort(convs, function(a, b)
			return a.mtime < b.mtime
		end) -- ascending order
	elseif sorting == "last" then
		table.sort(convs, function(a, b)
			return a.mtime > b.mtime
		end) -- descending order
	else
		-- For sorting by name
		table.sort(convs, function(a, b)
			return a.name < b.name
		end)
	end

	-- Extract sorted names
	local sorted_names = {}
	for _, conv in ipairs(convs) do
		table.insert(sorted_names, conv.name)
	end

	return sorted_names
end

--- Load a saved conversation and notify subscribers.
--- # Preconditions:
--- - `.is_ready() == true`
--- @nodiscard
--- @param name string
--- @return boolean success, string? reason
function ConversationManager.load_conversation(name)
	assert(ConversationManager.is_ready())
	local fname = conv_path .. "/" .. name .. ".json"
	if vim.fn.filereadable(fname) == 0 then
		return false, "Conversation does not exist"
	end
	local content = vim.fn.readfile(fname)
	local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
	if ok and data.messages then
		current_conversation = { name = name, messages = data.messages, type = "listed" }
		save_last(name)
		ConversationManager.on_conversation_switch:dispatch({
			conversation = current_conversation,
		})
		return true
	end
	return false, data
end

--- Load the last conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- @nodiscard
--- @return boolean success, string? reason
function ConversationManager.load_last_conversation()
	assert(ConversationManager.is_ready())
	if vim.fn.filereadable(last_conv_file) == 0 then
		return false, "No previous conversation"
	end
	local lines = vim.fn.readfile(last_conv_file)
	local name = lines[1]
	if current_conversation and current_conversation.name == name then
		return true
	end
	return ConversationManager.load_conversation(name)
end

--- Delete a conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- @nodiscard
--- @return boolean success, string? reason
function ConversationManager.delete_conversation(name)
	assert(ConversationManager.is_ready())
	local fname = conv_path .. "/" .. name .. ".json"
	if vim.fn.filereadable(fname) == 0 then
		return false, "Conversation does not exist"
	end
	local success = vim.fn.delete(fname) == 0
	if success and current_conversation and current_conversation.name == name then
		current_conversation = nil
		ConversationManager.on_conversation_switch:dispatch({ conversation = current_conversation })
	end
	return success
end

--- Convert the current unlisted conversation to a listed conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_conversation() == true`
--- - `.get_current_conversation().type == "unlisted"`
--- @nodiscard
--- @return boolean success, string? reason
function ConversationManager.convert_current_conversation_to_listed(name)
	assert(ConversationManager.is_ready())
	assert(current_conversation)
	assert(current_conversation.type == "unlisted")
	local fname = conv_path .. "/" .. name .. ".json"
	if vim.fn.filereadable(fname) ~= 0 then
		return false, "File already exists"
	end
	current_conversation.name = name
	current_conversation.type = "listed"
	local ok, reason = ConversationManager.save_current_conversation()
	if not ok then
		vim.notify(reason or "Unknown error", vim.log.levels.WARN)
	end
	return true
end

--- Rename a listed conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_conversation() == true`
--- - `.get_current_conversation().type == "listed"`
--- @nodiscard
--- @return boolean success, string? reason
function ConversationManager.rename_listed_conversation(name, new_name)
	assert(ConversationManager.is_ready())
	assert(current_conversation)
	assert(current_conversation.type == "listed")
	local fname = conv_path .. "/" .. name .. ".json"
	if vim.fn.filereadable(fname) == 0 then
		return false, "Conversation does not exist"
	end
	local new_fname = conv_path .. "/" .. new_name .. ".json"
	if vim.fn.filereadable(new_fname) ~= 0 then
		return false, "Target conversation already exists"
	end
	local success = vim.fn.rename(fname, new_fname) == 0
	if success and current_conversation and current_conversation.name == name then
		current_conversation.name = new_name
		return true
	end
	return false, "Unknown error while saving"
end

--- Save the current conversation to disk.
--- # Preconditions
--- - `.is_ready() == true`
--- - `.has_conversation() == true`
--- - `.get_current_conversation().type == "listed"|"project"`
--- @nodiscard
--- @return boolean success, string? reason
function ConversationManager.save_current_conversation()
	assert(ConversationManager.is_ready())
	assert(current_conversation)
	assert(current_conversation.type ~= "unlisted")
	if current_conversation.type == "listed" then
		local fname = conv_path .. "/" .. current_conversation.name .. ".json"
		vim.fn.writefile({ vim.fn.json_encode({ messages = current_conversation.messages }) }, fname)
		return true
	elseif current_conversation.type == "project" then
		-- TODO: implement
		return false, "Saving project conversations is not supported yet"
	end
	error("Unknown conversation type")
end

--- Create a new listed conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- @param name string?
function ConversationManager.new_listed_conversation(name)
	assert(ConversationManager.is_ready())
	name = name or os.date("%Y-%m-%d_%H-%M-%S") --[[@as string]]
	local messages = { { role = "system", content = initial_system_message } }
	current_conversation = { name = name, messages = messages, type = "listed" }
	local ok, reason = ConversationManager.save_current_conversation()
	if not ok then
		vim.notify(reason or "Unknown error", vim.log.levels.WARN)
	end
	save_last(name)
	ConversationManager.on_conversation_switch:dispatch({
		conversation = current_conversation,
	})
end

--- Create a new unlisted conversation.
--- # Preconditions:
--- - `.is_ready() == true`
function ConversationManager.new_unlisted_conversation()
	assert(ConversationManager.is_ready())
	local messages = { { role = "system", content = initial_system_message } }
	current_conversation = { name = "", messages = messages, type = "unlisted" }
	ConversationManager.on_conversation_switch:dispatch({ conversation = current_conversation })
end

--- Load last conversation or create a new unlisted conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- @return boolean loaded
function ConversationManager.load_last_or_create_new()
	if not ConversationManager.load_last_conversation() then
		ConversationManager.new_unlisted_conversation()
		return false
	end
	return true
end

--- Append a message to the current conversation.
--- # Preconditions:
--- - `.has_current_conversation() == true`
--- @param message Message
function ConversationManager.add_message(message)
	assert(current_conversation)
	table.insert(current_conversation.messages, message)
	ConversationManager.on_new_message:dispatch({ new_message = message })
end

--- Extend the last message of the current conversation.
--- # Preconditions:
--- - `.has_current_conversation() == true`
--- @nodiscard
--- @param msg_delta string
--- @return boolean success, string? reason
function ConversationManager.extend_last_message(msg_delta)
	assert(current_conversation)
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
	return true
end

--- Delete the last message of the current conversation.
--- # Preconditions:
--- - `ConversationManager.is_ready() == true`
--- - `ConversationManager.has_conversation() == true`
function ConversationManager.delete_last_message()
	assert(ConversationManager.is_ready())
	assert(current_conversation)
	local message_count = #current_conversation.messages
	if message_count == 0 then
		return
	end
	table.remove(current_conversation.messages, message_count)
	ConversationManager.on_conversation_switch:dispatch({
		conversation = current_conversation,
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

--- Determine whether there is an active conversation.
--- @nodiscard
--- @return boolean has_conversation
function ConversationManager.has_conversation()
	return current_conversation ~= nil
end

--- Determine whether the conversation manager is ready to generate a new response.
--- @nodiscard
--- @return boolean ready
function ConversationManager.is_ready()
	return not current_response or current_response.complete
end

--- Generate a response for the current conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_current_conversation() == true`
--- @param on_finish fun(conversation: Conversation)?
function ConversationManager.generate_response(on_finish)
	assert(ConversationManager.is_ready())
	assert(current_conversation)
	current_response = ChatCompletions.post_request(model, current_conversation.messages, function(message)
		ConversationManager.add_message(message)
		if on_finish then
			on_finish(current_conversation)
		end
	end)
end

local function create_update_timer(callback)
	local timer, error_msg, err_name = vim.uv.new_timer()
	if not timer then
		error(err_name .. ": " .. error_msg)
	end

	local accumulator = nil
	local updater = {}

	function updater.append(content)
		if accumulator then
			accumulator = accumulator .. content
		else
			accumulator = content
		end
	end

	function updater.stop()
		timer:stop()
		updater.commit()
	end

	function updater.commit()
		if accumulator then
			callback(accumulator)
			accumulator = nil
		end
	end

	local function on_timer_expired()
		if accumulator then
			updater.commit()
		end
	end

	timer:start(250, 250, vim.schedule_wrap(on_timer_expired))

	return updater
end

--- Generate a response and stream the result to the current conversation.
--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_conversation() == true`
--- @param on_finish fun(conversation: Conversation)?
function ConversationManager.generate_streaming_response(on_finish)
	assert(ConversationManager.is_ready())
	assert(current_conversation)

	local updater = create_update_timer(function(accumulated_content)
		local ok, reason = ConversationManager.extend_last_message(accumulated_content)
		if not ok then
			vim.notify("Error in comitting accumulated response: " .. reason, vim.log.levels.ERROR)
		end
	end)

	local response_status = ChatCompletions.post_streaming_request(
		model,
		current_conversation.messages,
		function(_, chunk)
			if #chunk.choices > 0 then
				local delta = chunk.choices[1].delta
				assert(delta)
				if not delta.role then
					if delta.content then
						updater.append(delta.content)
					end
				else
					updater.commit()
					ConversationManager.add_message({
						role = delta.role,
						content = delta.content,
					})
				end
			end
		end,
		function(_)
			updater.stop()
			if on_finish then
				on_finish(current_conversation)
			end
		end
	)
	current_response = response_status
end

--- @type EventDispatcher<MessageExtendEvent>
ConversationManager.on_message_extend = EventDispatcher:new()
--- @type EventDispatcher<NewMessageEvent>
ConversationManager.on_new_message = EventDispatcher:new()
--- @type EventDispatcher<ConversationSwitchEvent>
ConversationManager.on_conversation_switch = EventDispatcher:new()

return ConversationManager
