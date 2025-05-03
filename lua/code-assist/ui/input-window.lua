local BaseWindow = require("code-assist.ui.base-window")
local EventDispatcher = require("code-assist.event-dispatcher")

--- @class InputWindow : BaseWindow
--- @field new fun(win: InputWindow, orientation: WindowOrientation?): InputWindow
--- @field on_submit EventDispatcher<string>
local InputWindow = {}
InputWindow.__index = InputWindow
setmetatable(InputWindow, BaseWindow)

function InputWindow:new(orientation)
	--- @type InputWindow
	local new = BaseWindow.new(self, orientation) --[[@as InputWindow]]
	local buf = new:get_buf()
	new.on_submit = EventDispatcher:new()

	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].modifiable = true
	vim.bo[buf].swapfile = false
	return new
end

function InputWindow:commit()
	local content = table.concat(vim.api.nvim_buf_get_lines(self:get_buf(), 0, -1, true), "\n")
	if content ~= "" then
		self.on_submit:dispatch(content)
	end
end

function InputWindow:clear()
	vim.api.nvim_buf_set_lines(self:get_buf(), 0, -1, true, {})
end

return InputWindow
