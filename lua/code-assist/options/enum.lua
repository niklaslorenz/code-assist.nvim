local Option = require("code-assist.options.option")
local Util = require("code-assist.util")

--- @class ca.opt.Enum: ca.opt.Option
--- @field new fun(e: ca.opt.Enum, name: string, values: string[], value: string): ca.opt.Enum
--- @field display fun(e: ca.opt.Enum): ca.opt.DisplayItem[]
--- @field get_value fun(e: ca.opt.Enum): string
--- @field set_value fun(e: ca.opt.Enum, value: any)
--- @field on_edit fun(e: ca.opt.Enum, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field value string
--- @field values string[]
local Enum = {}
Enum.__index = Enum
setmetatable(Enum, Option)

function Enum:new(name, values, value)
  local new = Option.new(self, name) --[[@as ca.opt.Enum]]
  new.value = value
  new.values = values
  return new
end

function Enum:display()
  --- @type ca.opt.DisplayItem
  local item = {
    text = "- " .. self.name .. ": " .. self.value,
    option = self,
  }
  return { item }
end

function Enum:get_value()
  return self.value
end

function Enum:set_value(value)
  if value == nil then
    return
  end
  if type(value) == "number" then
    self.value = self.values[value]
  end
  if type(value) ~= "string" then
    error("Expected type string but got " .. type(value))
  end
  if Util.list_find(self.values, value) == -1 then
    error("Invalid enum value: " .. value .. ". Allowed values are: " .. table.concat(self.values, ", "))
  end
  self.value = value
end

function Enum:on_edit(async_modified_callback)
  vim.ui.select(self.values, {
    prompt = self.name,
  }, function(item, _)
    if item == nil or item == self.value then
      return
    end
    self:set_value(item)
    async_modified_callback(true, true)
  end)
  return false, false
end

return Enum
