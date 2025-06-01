local Option = require("code-assist.options.option")

--- @class ca.opt.Checkbox: ca.opt.Option
--- @field new fun(box: ca.opt.Checkbox, name: string, value: boolean): ca.opt.Checkbox
--- @field display fun(box: ca.opt.Checkbox): ca.opt.DisplayItem[]
--- @field get_value fun(box: ca.opt.Checkbox): boolean
--- @field set_value fun(box: ca.opt.Checkbox, value: any)
--- @field on_edit fun(box: ca.opt.Checkbox, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field value boolean
local Checkbox = {}
Checkbox.__index = Checkbox
setmetatable(Checkbox, Option)

function Checkbox:new(name, value)
	local new = Option.new(self, name) --[[@as ca.opt.Checkbox]]
	new.value = value
	return new
end

function Checkbox:display()
	local text = (self.value and "- [x] " or "- [ ] ") .. self.name
	--- @type ca.opt.DisplayItem
	local display_item = {
		text = text,
		option = self,
	}
	return { display_item }
end

function Checkbox:get_value()
	return self.value
end

function Checkbox:set_value(value)
	if value == nil then
		return
	end
	if type(value) ~= "boolean" then
		error("Expected boolean, but got " .. type(value))
	end
	self.value = value
end

function Checkbox:on_edit(_)
	self.value = not self.value
	return true, true
end

return Checkbox
