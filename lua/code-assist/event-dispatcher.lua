--- @class EventDispatcher<T>: {_subscribers: fun(event: T)[],
--- subscribe: fun(self: EventDispatcher<T>, callback: fun(event: T)),
--- unsubscribe: fun(self: EventDispatcher<T>, callback: fun(event: T)),
--- dispatch: fun(self: EventDispatcher<T>, event: T)}

local EventDispatcher = {}
EventDispatcher.__index = EventDispatcher

--- @generic T
--- @return EventDispatcher<T>
function EventDispatcher:new()
	local obj = { _subscribers = {} }
	setmetatable(obj, self)
	return obj
end

--- @generic T
--- @param self EventDispatcher<T>
--- @param callback fun(event: T)
function EventDispatcher.subscribe(self, callback)
	table.insert(self._subscribers, callback)
end

--- @generic T
--- @param self EventDispatcher<T>
--- @param event T
function EventDispatcher.dispatch(self, event)
	for _, cb in ipairs(self._subscribers) do
		cb(event)
	end
end

return EventDispatcher
