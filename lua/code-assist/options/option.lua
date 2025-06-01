--- @class ca.opt.DisplayItem
--- @field text string
--- @field option ca.opt.Option

--- @class ca.opt.Option
--- @field new fun(opt: ca.opt.Option, name: string): ca.opt.Option
--- @field display fun(opt: ca.opt.Option): ca.opt.DisplayItem[]
--- @field get_value fun(opt: ca.opt.Option): fun(opt: ca.opt.Option): any
--- @field set_value fun(opt: ca.opt.Option, value: any)
--- @field on_edit fun(opt: ca.opt.Option, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field name string
local Option = {}
Option.__index = Option

function Option:new(name)
	--- @diagnostic disable: missing-fields
	local new = {
		name = name,
	} --[[@as ca.opt.Option]]
	setmetatable(new, self)
	return new
end

function Option:display()
	error("Subclasses are expected to override this function")
end

function Option:on_edit(_)
	error("Subclasses are expected to override this function")
end

function Option:get_value()
	error("Subclasses are expected to override this function")
end

function Option:set_value(_)
	error("Subclasses are expected to override this function")
end

return Option
