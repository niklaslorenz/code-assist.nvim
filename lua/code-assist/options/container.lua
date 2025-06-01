local Option = require("code-assist.options.option")

--- @class ca.opt.Container: ca.opt.Option
--- @field new fun(cont: ca.opt.Container, name: string, value: ca.opt.Option[], expanded_by_default: boolean?): ca.opt.Container
--- @field get_value fun(cont: ca.opt.Container): table
--- @field display fun(cont: ca.opt.Container): ca.opt.DisplayItem[]
--- @field on_edit fun(cont: ca.opt.Container, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field value ca.opt.Option[]
--- @field is_expanded boolean
local Container = {}
Container.__index = Container
setmetatable(Container, Option)

function Container:new(name, value, expanded_by_default)
  local new = Option.new(self, name) --[[@as ca.opt.Container]]
  new.value = value
  if expanded_by_default then
    new.is_expanded = true
  else
    new.is_expanded = false
  end
  return new
end

function Container:get_value()
  local value = {}
  for _, item in ipairs(self.value) do
    value[item.name] = item:get_value()
  end
  return value
end

function Container:set_value(value)
  if value == nil then
    return
  end
  if type(value) ~= "table" then
    error("Expected table, but got " .. type(value))
  end
  for _, item in ipairs(self.value) do
    local val = value[item.name]
    if val ~= nil then
      item.set_value(val)
    end
  end
end

function Container:on_edit(_)
  self.is_expanded = not self.is_expanded
  return false, true
end

function Container:display()
  --- @type ca.opt.DisplayItem
  local self_display = {
    text = "> " .. self.name,
    option = self,
  }
  local items = { self_display }
  if self.is_expanded then
    for _, item in ipairs(self.value) do
      local displayed_item = item:display()
      for _, child in ipairs(displayed_item) do
        table.insert(items, child)
      end
    end
  end
  return items
end

return Container
