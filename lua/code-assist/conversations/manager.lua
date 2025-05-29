local Observer = require("code-assist.conversations.observer")

--- @class ConversationManager2
--- Methods
--- @field set_conversation fun(conv: Conversation?)
--- @field get_conversation fun(): Conversation?
--- @field is_ready fun(): boolean
--- @field has_conversation fun(): boolean
--- Attributes
--- @field observer ConversationObserver
--- @field private _current_conversation Conversation?
local ConversationManager = {
	observer = Observer:new(),
	_current_conversation = nil,
}
ConversationManager.__index = ConversationManager

function ConversationManager.set_conversation(conv)
	if ConversationManager._current_conversation then
		ConversationManager._current_conversation:unload()
	end
	ConversationManager.observer:observe(conv)
	ConversationManager._current_conversation = conv
end

function ConversationManager.get_conversation()
	return ConversationManager._current_conversation
end

function ConversationManager.is_ready()
	return ConversationManager._current_conversation == nil or ConversationManager._current_conversation:is_ready()
end

function ConversationManager.has_conversation()
	return ConversationManager._current_conversation ~= nil
end

return ConversationManager
