local BaseWindow = require("code-assist.ui.base-window")
local EventDispatcher = require("code-assist.event-dispatcher")

--- @class InputWindow : BaseWindow
--- @field new fun(win: InputWindow, orientation: WindowOrientation?): InputWindow
--- @field submit fun(win: InputWindow)
--- @field clear fun(win: InputWindow)
--- @field on_submit EventDispatcher<string>
local InputWindow = {}
InputWindow.__index = InputWindow
setmetatable(InputWindow, BaseWindow)

function InputWindow:new(orientation)
	--- @type InputWindow
	local new = BaseWindow.new(self, orientation) --[[@as InputWindow]]
	new.on_submit = EventDispatcher:new()
	return new
end

function InputWindow:_setup_buf()
	BaseWindow._setup_buf(self)
	local buf = self:get_buf()
	assert(buf)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].modifiable = true
	vim.bo[buf].swapfile = false
end

function InputWindow:submit()
	local buf = self:get_buf()
	assert(buf)
	local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, true), "\n")
	if content ~= "" then
		self.on_submit:dispatch(content)
	end
end

function InputWindow:redraw() end

function InputWindow:clear()
	local buf = self:get_buf()
	assert(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, {})
end

return InputWindow
