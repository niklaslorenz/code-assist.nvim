local InputWindow = require("code-assist.ui.input-window")

--- @class ca.ui.InputPopup: InputWindow
--- @field new fun(win: ca.ui.InputPopup, content: string, title: string, callback: fun(text: string)): ca.ui.InputPopup
--- @field content string
local InputPopup = {}
InputPopup.__index = InputPopup
setmetatable(InputPopup, InputWindow)

function InputPopup:new(content, title, callback)
	local new = InputWindow.new(self, "float") --[[@as ca.ui.InputPopup]]
	new.track_parent_window = true
	new.content = content
	new:set_title(title)
	new.on_submit:subscribe(callback)
	return new
end

function InputPopup:_setup_buf()
	InputWindow._setup_buf(self)
	local buf = self:get_buf()
	assert(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(self.content, "\n"))
	local opts = { buffer = self:get_buf(), silent = true, noremap = true }
	vim.keymap.set("n", "q", function()
		self:dispose()
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		self:dispose()
	end, opts)
	vim.keymap.set({ "n", "i" }, "<CR><CR>", function()
		self:submit()
		self:dispose()
	end, opts)
end

return InputPopup
