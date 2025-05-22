local EventDispatcher = require("code-assist.event-dispatcher")
local ChatCompletions = require("code-assist.assistant.chat-completions")
local Options = require("code-assist.options")
local Message = require("code-assist.conversations.message")

local model = Options.model

--- @class ConversationManager
--- @field new fun(): ConversationManager
--- @field get_current_conversation fun(): Conversation?
--- @field has_conversation fun(): boolean
--- @field is_ready fun(): boolean
--- @field get_status fun(): ConversationManagerStatus?
--- @field add_item fun(item: ConversationItem)
--- @field delete_item fun(): ConversationItem?
--- @field extend_message fun(delta: string)
--- @field query fun(on_finish: fun(conv: Conversation)?)
--- @field stream_query fun(on_finish: fun(conv: Conversation)?)
--- @field set_conversation fun(conv: Conversation?)
--- @field on_conversation_switch EventDispatcher<ConversationSwitchEvent>
--- @field on_message_extended EventDispatcher<MessageExtendEvent>
--- @field on_new_item EventDispatcher<NewItemEvent>
--- @field on_item_deleted EventDispatcher<ItemDeletedEvent>
--- @field _status ConversationManagerStatus?
--- @field _current_conversation Conversation?
local ConversationManager = {
	on_conversation_switch = EventDispatcher:new(),
	on_message_extended = EventDispatcher:new(),
	on_new_item = EventDispatcher:new(),
	on_item_deleted = EventDispatcher:new(),
	_status = nil,
	_current_conversation = nil,
}

function ConversationManager.get_current_conversation()
	return ConversationManager._current_conversation
end

function ConversationManager.has_conversation()
	return ConversationManager._current_conversation ~= nil
end

function ConversationManager.is_ready()
	return ConversationManager._status == nil or ConversationManager._status.complete
end

function ConversationManager.get_status()
	return ConversationManager._status
end

function ConversationManager.add_item(item)
	assert(ConversationManager.has_conversation())
	table.insert(ConversationManager._current_conversation.content, item)
	ConversationManager.on_new_item:dispatch({ new_item = item })
end

function ConversationManager.delete_item()
	local conv = ConversationManager._current_conversation
	assert(conv)
	local index = #conv.content
	local item = conv.content[index]
	table.remove(conv.content, index)
	ConversationManager.on_item_deleted:dispatch({ deleted_item = item, deleted_index = index })
	return item
end

function ConversationManager.extend_message(delta)
	local conv = ConversationManager._current_conversation
	assert(conv)
	local index = #conv.content
	local item = conv.content[index]
	assert(item:is(Message))
	--- @cast item ConversationMessage
	local old_content = item.content
	item.content = item.content .. delta
	ConversationManager.on_message_extended:dispatch({
		delta = delta,
		message = item,
		old_content = old_content,
	})
end

--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_current_conversation() == true`
--- @param on_finish fun(conversation: Conversation)?
function ConversationManager.query(on_finish)
	assert(ConversationManager.is_ready())
	assert(ConversationManager._current_conversation)
	ConversationManager._status = ChatCompletions.post_request(
		model,
		ConversationManager._current_conversation.content,
		function(message)
			ConversationManager.add_item(message)
			if on_finish then
				on_finish(ConversationManager._current_conversation)
			end
		end
	)
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

--- # Preconditions:
--- - `.is_ready() == true`
--- - `.has_conversation() == true`
function ConversationManager.stream_query(on_finish)
	assert(ConversationManager.is_ready())
	assert(ConversationManager._current_conversation)

	local updater = create_update_timer(function(accumulated_content)
		ConversationManager.extend_message(accumulated_content)
	end)

	local response_status = ChatCompletions.post_streaming_request(
		model,
		ConversationManager._current_conversation.content,
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
					ConversationManager.add_item(Message:new(delta.role, "assistant", delta.content))
				end
			end
		end,
		function(_)
			updater.stop()
			if on_finish then
				on_finish(ConversationManager._current_conversation)
			end
		end
	)
	ConversationManager._status = response_status
end

function ConversationManager.set_conversation(conv)
	ConversationManager._current_conversation = conv
	ConversationManager.on_conversation_switch:dispatch({ conversation = conv })
end

return ConversationManager
