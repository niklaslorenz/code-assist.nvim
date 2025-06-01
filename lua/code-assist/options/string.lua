local Option = require("code-assist.options.option")
local InputPopup = require("code-assist.ui.popups.input-popup")

--- @class ca.opt.String: ca.opt.Option
--- @field new fun(txt: ca.opt.String, name: string, value: string): ca.opt.String
--- @field display fun(txt: ca.opt.String): ca.opt.DisplayItem[]
--- @field get_value fun(txt: ca.opt.String): string
--- @field set_value fun(txt: ca.opt.String, value: any)
--- @field on_edit fun(txt: ca.opt.String, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field value string
local StringOption = {}
StringOption.__index = StringOption
setmetatable(StringOption, Option)

function StringOption:new(name, value)
  local new = Option.new(self, name) --[[@as ca.opt.String]]
  new.value = value
  return new
end

function StringOption:display()
  --- @type ca.opt.DisplayItem
  local item = {
    text = "- " .. self.name .. ": " .. self.value,
    option = self,
  }
  return { item }
end

function StringOption:get_value()
  return self.value
end

function StringOption:set_value(value)
  if value == nil then
    return
  end
  if type(value) ~= "string" then
    error("Expected type string but got " .. type(value))
  end
  self.value = value
end

function StringOption:on_edit(async_modified_callback)
  InputPopup:new(self.value, self.name, function(value)
    self:set_value(value)
    async_modified_callback(true, true)
  end):show()
  return false, false
end

return StringOption
