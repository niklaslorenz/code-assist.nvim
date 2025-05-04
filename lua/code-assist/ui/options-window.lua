local BaseWindow = require("code-assist.ui.base-window")
local EventDispatcher = require("code-assist.event-dispatcher")

--- @class OptionsWindowOnSelectEvent
--- @field option string
--- @field new_status boolean

--- @class OptionsWindow : BaseWindow
--- @field new fun(win: OptionsWindow, options: table<string, boolean>, header: string, orientation: WindowOrientation?): OptionsWindow
--- @field set_options fun(win: OptionsWindow, options: string[])
--- @field select fun(win: OptionsWindow)
--- @field submit fun(win: OptionsWindow)
--- @field private _options table<string, boolean>
--- @field private _option_names string[]
--- @field on_submit EventDispatcher<table<string, boolean>>
--- @field on_select EventDispatcher<OptionsWindowOnSelectEvent>
local OptionsWindow = {}
OptionsWindow.__index = OptionsWindow
setmetatable(OptionsWindow, BaseWindow)

--- @param window OptionsWindow
local function setup_keymaps(window)
  local opts = { buffer = window:get_buf(), silent = true, noremap = true }
  vim.keymap.set("n", "q", function()
    window:submit()
  end, opts)
  vim.keymap.set("n", "x", function()
    window:select()
  end, opts)
  vim.keymap.set("n", "<Space>", function()
    window:select()
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    window:select()
  end, opts)
end

function OptionsWindow:new(options, header, orientation)
  local new = BaseWindow.new(self, orientation) --[[@as OptionsWindow]]
  new._options = options
  new.on_submit = EventDispatcher:new()
  new.on_select = EventDispatcher:new()
  local lines = { header }
  local option_names = {}
  for k, v in pairs(options) do
    local status = v and "- [x] " or "- [ ] "
    table.insert(lines, status .. k)
    table.insert(option_names, k)
  end
  new._option_names = option_names
  local buf = new:get_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  setup_keymaps(new)
  return new
end

function OptionsWindow:select()
  local win = self:get_win()
  assert(win)
  local current_line = vim.api.nvim_win_get_cursor(win)[1] - 1
  if current_line == 0 then
    return
  end
  local buf = self:get_buf()
  local name = self._option_names[current_line]
  local selected = self._options[name]
  self._options[name] = not selected
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(
    buf,
    current_line,
    current_line + 1,
    true,
    { (selected and "- [ ] " or "- [x] ") .. name }
  )
  vim.bo[buf].modifiable = false
  self.on_select:dispatch({ option = name, new_status = not selected })
end

function OptionsWindow:submit()
  self.on_submit:dispatch(self._options)
  self:dispose()
end

return OptionsWindow
