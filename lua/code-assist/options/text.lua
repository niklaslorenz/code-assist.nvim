local Option = require("code-assist.options.option")
local InputPopup = require("code-assist.ui.popups.input-popup")

--- @class ca.opt.Text: ca.opt.Option
--- @field new fun(txt: ca.opt.Text, name: string, value: string): ca.opt.Text
--- @field display fun(txt: ca.opt.Text): ca.opt.DisplayItem[]
--- @field get_value fun(txt: ca.opt.Text): string
--- @field set_value fun(txt: ca.opt.Text, value: any)
--- @field on_edit fun(txt: ca.opt.Text, async_modified_callback: fun(value_changed: boolean, display_changed: boolean)): value_changed: boolean, display_changed: boolean
--- @field value string
local Text = {}
Text.__index = Text
setmetatable(Text, Option)

function Text:new(name, value)
  local new = Option.new(self, name) --[[@as ca.opt.Text]]
  new.value = value
  return new
end

function Text:display()
  --- @type ca.opt.DisplayItem[]
  local items = {}
  for i, line in ipairs(vim.split(self.value, "\n")) do
    local text = i == 1 and "- " .. self.name .. ": " .. line or "  " .. line
    items[i] = {
      text = text,
      option = self,
    }
  end
  return items
end

function Text:get_value()
  return self.value
end

function Text:set_value(value)
  if value == nil then
    return
  end
  if type(value) ~= "string" then
    error("Expected type string but got " .. type(value))
  end
  self.value = value
end

function Text:on_edit(async_modified_callback)
  InputPopup:new(self.value, self.name, function(value)
    self:set_value(value)
    async_modified_callback(true, true)
  end):show()
  return false, false
end

return Text
