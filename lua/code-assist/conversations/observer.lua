local EventDispatcher = require("code-assist.event-dispatcher")

--- @class ConversationObserver
--- Shared Methods
--- @field new fun(obs: ConversationObserver): ConversationObserver
--- Member Methods
--- @field observe fun(obs: ConversationObserver, conv: Conversation?)
--- Member fields
--- @field on_new_item EventDispatcher<ConversationNewItemEvent>
--- @field on_item_extended EventDispatcher<ConversationItemExtendedEvent>
--- @field on_item_deleted EventDispatcher<ConversationItemDeletedEvent>
--- @field on_conversation_switch EventDispatcher<ConversationSwitchEvent>
--- @field private _observed Conversation?
local ConversationObserver = {}
ConversationObserver.__index = ConversationObserver

function ConversationObserver:new()
	local new = {
		on_new_item = EventDispatcher:new(),
		on_item_extended = EventDispatcher:new(),
		on_item_deleted = EventDispatcher:new(),
		on_conversation_switch = EventDispatcher:new(),
		_observed = nil,
	}
	setmetatable(new, self)
	return new
end

function ConversationObserver:observe(conv)
	local old_conv = self._observed
	if self._observed then
		self._observed:remove_observer(self)
	end
	self._observed = nil
	if conv then
		self._observed = conv
		conv:add_observer(self)
	end
	self.on_conversation_switch:dispatch({
		new_conversation = conv,
		old_conversation = old_conv,
	})
end

return ConversationObserver
