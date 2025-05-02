local EventDispatcher = require("code-assist.event-dispatcher")

--- @class BaseWindow
--- @field new fun(win: BaseWindow, orientation: WindowOrientation?): BaseWindow
--- @field get_win fun(win: BaseWindow): integer?
--- @field get_buf fun(win: BaseWindow): integer
--- @field is_visible fun(win: ContentWindow): boolean
--- @field set_title fun(win: BaseWindow, title: string?)
--- @field show fun(win: BaseWindow, orientation: WindowOrientation?)
--- @field hide fun(win: BaseWindow)
--- @field scroll_to_bottom fun(win: BaseWindow)
--- @field increase_window_width fun(win: ContentWindow)
--- @field decrease_window_width fun(win: ContentWindow)
--- @field increase_window_height fun(win: ContentWindow)
--- @field decrease_window_height fun(win: ContentWindow)
--- @field on_visibility_change EventDispatcher<WindowStatus>
--- @field private _buf_id integer
--- @field private _win_id integer?
--- @field private _orientation WindowOrientation
--- @field private _title string?
local BaseWindow = {}
BaseWindow.__index = BaseWindow

function BaseWindow:new(orientation)
	if not orientation then
		orientation = "float"
	end
	local new = {
		on_visibility_change = EventDispatcher:new(),
		_buf_id = vim.api.nvim_create_buf(false, true),
		_win_id = nil,
		_orientation = orientation,
		_title = nil,
	}
	vim.bo[new._buf_id].buftype = "nofile"
	vim.bo[new._buf_id].swapfile = false
	setmetatable(new, self)
	return new
end

function BaseWindow:get_win()
	if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
		return self._win_id
	end
	return nil
end

function BaseWindow:get_buf()
	return self._buf_id
end

function BaseWindow:is_visible()
	return self:get_win() ~= nil
end

function BaseWindow:set_title(title)
	self._title = title
	local win = self:get_win()
	if win and self._orientation == "float" then
		local config = vim.api.nvim_win_get_config(win)
		config.title = title
		config.title_pos = "center"
		vim.api.nvim_win_set_config(win, config)
	end
end

function BaseWindow:show(orientation)
	local win = self:get_win()
	if not orientation then
		orientation = self._orientation
	end
	if win then
		if orientation == self._orientation then
			vim.api.nvim_set_current_win(win)
			return
		else
			self:hide()
		end
	end

	if orientation == "hsplit" then
		self._win_id = vim.api.nvim_open_win(self._buf_id, true, {
			vertical = false,
			split = "bottom",
		})
	elseif orientation == "vsplit" then
		self._win_id = vim.api.nvim_open_win(self._buf_id, true, {
			vertical = true,
			split = "right",
		})
	else
		local w = math.floor(vim.o.columns * 0.6)
		local h = math.floor(vim.o.lines * 0.6)
		local row = math.floor((vim.o.lines - h) / 2)
		local col = math.floor((vim.o.columns - w) / 2)
		local title_pos = nil
		if self._title ~= nil then
			title_pos = "center"
		end
		self._win_id = vim.api.nvim_open_win(self._buf_id, true, {
			relative = "editor",
			width = w,
			height = h,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = self._title,
			title_pos = title_pos,
		})
	end

	self._orientation = orientation
	self.on_visibility_change:dispatch("visible")
end

function BaseWindow:hide()
	local win = self:get_win()
	if not win then
		self._win_id = nil
		return
	end
	vim.api.nvim_win_close(win, true)
	self.on_visibility_change:dispatch("hidden")
end

function BaseWindow:scroll_to_bottom()
	local win = self:get_win()
	assert(win)
	local line_count = vim.api.nvim_buf_line_count(self._buf_id)
	vim.api.nvim_win_set_cursor(win, { line_count - 1, 0 })
end

function BaseWindow:increase_window_width()
	local win = self:get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.width then
		config.width = config.width + 10
	end
	vim.api.nvim_win_set_config(win, config)
end

function BaseWindow:increase_window_height()
	local win = self:get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.height then
		config.height = config.height + 5
	end
	vim.api.nvim_win_set_config(win, config)
end

function BaseWindow:decrease_window_width()
	local win = self:get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.width then
		config.width = config.width - 10
	end
	vim.api.nvim_win_set_config(win, config)
end

function BaseWindow:decrease_window_height()
	local win = self:get_win()
	if not win then
		return
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.height then
		config.height = config.height - 5
	end
	vim.api.nvim_win_set_config(win, config)
end

return BaseWindow
