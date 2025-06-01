local ListWindow = require("code-assist.ui.list-window")
local EventDispatcher = require("code-assist.event-dispatcher")

--- @class ca.ui.OptionsPopup: ListWindow
--- @field new fun(win: ca.ui.OptionsPopup, options: ca.opt.Option, title: string?, callback: fun(option: ca.opt.Option)): ca.ui.OptionsPopup
--- @field submit fun(win: ca.ui.OptionsPopup)
--- @field option ca.opt.Option
--- @field on_submit EventDispatcher<ca.opt.Option>
--- @field was_modified boolean
--- @field opts ca.opt.Option[]
local OptionsPopup = {}
OptionsPopup.__index = OptionsPopup
setmetatable(OptionsPopup, ListWindow)

--- @param opt ca.opt.Option
--- @return string[], ca.opt.Option[]
local function convert_option(opt)
	local lines = {}
	local opts = {}
	for i, item in ipairs(opt:display()) do
		lines[i] = item.text
		opts[i] = item.option
	end
	return lines, opts
end

function OptionsPopup:new(options, title, callback)
	local lines, opts = convert_option(options)
	local new = ListWindow.new(self, "float", nil, lines) --[[@as ca.ui.OptionsPopup]]
	new.track_parent_window = true
	new.option = options
	new.on_submit = EventDispatcher:new()
	new.opts = opts
	new.was_modified = false
	new.on_submit:subscribe(callback)
	new:set_title(title)
	return new
end

function OptionsPopup:submit()
	if self.was_modified then
		self.on_submit:dispatch(self.option)
	end
	self:dispose()
end

function OptionsPopup:_select_hovered()
	local hovered = self:get_hovered_index()
	if hovered > 0 then
		local opt = self.opts[hovered]
		local val_change, disp_change = opt:on_edit(function(vc, dc)
			if vc then
				self.was_modified = true
			end
			if dc then
				local lines, opts = convert_option(self.option)
				self:set_content(lines)
				self.opts = opts
			end
		end)
		if val_change then
			self.was_modified = true
		end
		if disp_change then
			local lines, opts = convert_option(self.option)
			self:set_content(lines)
			self.opts = opts
		end
	end
end

function OptionsPopup:_setup_buf()
	ListWindow._setup_buf(self)
	local buf = self:get_buf()
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].bufhidden = "wipe"
	local opts = { buffer = self:get_buf(), silent = true, noremap = true }
	vim.keymap.set("n", "q", function()
		self:submit()
	end, opts)
	vim.keymap.set("n", "x", function()
		self:_select_hovered()
	end, opts)
	vim.keymap.set("n", "<Space>", function()
		self:_select_hovered()
	end, opts)
	vim.keymap.set("n", "<CR>", function()
		self:_select_hovered()
	end, opts)
end

return OptionsPopup
