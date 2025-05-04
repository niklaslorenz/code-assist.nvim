local EventDispatcher = require("code-assist.event-dispatcher")

--- @alias WindowOrientation "hsplit"|"vsplit"|"float"

--- @alias WindowStatus "visible"|"hidden"

--- @class WindowShowOptions
--- @field relative_width number?
--- @field relative_height number?
--- @field origin integer|BaseWindow?
--- @field orientation WindowOrientation?

--- @class BaseWindow
--- @field new fun(win: BaseWindow, orientation: WindowOrientation?): BaseWindow
--- @field dispose fun(win: BaseWindow)
--- @field get_win fun(win: BaseWindow): integer?
--- @field get_buf fun(win: BaseWindow): integer
--- @field get_orientation fun(win: BaseWindow): WindowOrientation
--- @field is_visible fun(win: BaseWindow): boolean
--- @field set_title fun(win: BaseWindow, title: string?)
--- @field show fun(win: BaseWindow, opts: WindowShowOptions?)
--- @field hide fun(win: BaseWindow)
--- @field scroll_to_bottom fun(win: BaseWindow)
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

function BaseWindow:dispose()
	if self:is_visible() then
		self:hide()
	end
	vim.api.nvim_buf_delete(self._buf_id, { force = true })
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

function BaseWindow:get_orientation()
	return self._orientation
end

function BaseWindow:is_visible()
	return self:get_win() ~= nil
end

function BaseWindow:set_title(title)
	self._title = title
	local win = self:get_win()
	if win and self._orientation == "float" then
		local config = vim.api.nvim_win_get_config(win)
		config.title = title or ""
		config.title_pos = title ~= nil and "center" or nil
		vim.api.nvim_win_set_config(win, config)
	end
end

function BaseWindow:show(opts)
	opts = opts or {}
	local win = self:get_win()
	local orientation = opts.orientation or self._orientation

	local origin_window = opts.origin
	if origin_window ~= nil then
		if type(origin_window) ~= "number" then
			origin_window = origin_window --[[@as BaseWindow]]:get_win()
		end
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
		local height
		if opts.relative_height then
			height = math.floor(opts.relative_height * vim.api.nvim_win_get_height(origin_window or 0))
		end
		self._win_id = vim.api.nvim_open_win(self._buf_id, true, {
			vertical = false,
			split = "below",
			height = height,
			win = origin_window,
		})
	elseif orientation == "vsplit" then
		local width
		if opts.relative_width then
			width = math.floor(opts.relative_width * vim.api.nvim_win_get_width(origin_window or 0))
		end
		self._win_id = vim.api.nvim_open_win(self._buf_id, true, {
			vertical = true,
			split = "right",
			width = width,
			win = origin_window,
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
	vim.api.nvim_win_set_cursor(win, { line_count, 0 })
end

return BaseWindow
