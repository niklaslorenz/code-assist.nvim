local EventDispatcher = require("code-assist.event-dispatcher")

--- @class Future<T>: {
--- completed: boolean,
--- object:T?,
--- on_complete: EventDispatcher<T>,
--- complete: fun(self: Future<T>, value: T)}
local Future = {}
Future.__index = Future

--- @generic T
--- @return Future<T>
function Future:new()
	local new = {
		completed = false,
		obj = nil,
		on_complete = EventDispatcher:new(),
	}
	setmetatable(new, self)
	return new
end

--- @generic T
--- @param self Future<T>
--- @param value T
function Future.complete(self, value)
	self.completed = true
	self.object = value
	self.on_complete:dispatch(value)
end

return Future
