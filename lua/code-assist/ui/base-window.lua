local EventDispatcher = require("code-assist.event-dispatcher")

--- @alias WindowBufferSetupEvent integer

--- @alias WindowOrientation "hsplit"|"vsplit"|"float"

--- @alias WindowStatus "visible" Indicates that the window was opened
--- |"hidden" Indicates that the window was hidden
--- |"layout" Indicates that the window layout has changed

--- @class WindowShowOptions
--- @field relative_width number?
--- @field relative_height number?
--- @field origin integer|BaseWindow?
--- @field orientation WindowOrientation?
--- @field float_width number?
--- @field float_height number?

--- @class BaseWindow
--- Constructor
--- @field new fun(win: BaseWindow, orientation: WindowOrientation?): BaseWindow
--- Destructor
--- @field dispose fun(win: BaseWindow)
--- Public Methods
--- @field get_win fun(win: BaseWindow): integer?
--- @field get_buf fun(win: BaseWindow): integer?
--- @field get_orientation fun(win: BaseWindow): WindowOrientation?
--- @field is_visible fun(win: BaseWindow): boolean
--- @field has_buffer fun(win: BaseWindow): boolean
--- @field set_title fun(win: BaseWindow, title: string?)
--- @field redraw fun(win: BaseWindow)
--- @field show fun(win: BaseWindow, opts: WindowShowOptions?)
--- @field hide fun(win: BaseWindow)
--- @field scroll_to_bottom fun(win: BaseWindow)
--- Private Methods
--- @field protected _setup_buf fun(win: BaseWindow)
--- @field protected _setup_autocmds fun(win: BaseWindow)
--- Public Fields
--- @field on_visibility_change EventDispatcher<WindowStatus>
--- @field on_buffer_setup EventDispatcher<WindowBufferSetupEvent>
--- @field track_parent_window boolean
--- Private fields
--- @field _augroup integer?
--- @field private _buf_id integer?
--- @field private _win_id integer?
--- @field private _last_show_opts WindowShowOptions
--- @field private _orientation WindowOrientation?
--- @field private _default_orientation WindowOrientation
--- @field private _parent_window integer?
--- @field private _title string?
local BaseWindow = {}
BaseWindow.__index = BaseWindow

function BaseWindow:new(default_orientation)
	if not default_orientation then
		default_orientation = "float"
	end
	local new = {
		on_visibility_change = EventDispatcher:new(),
		on_buffer_setup = EventDispatcher:new(),
		track_parent_window = false,
		_augroup = nil,
		_buf_id = nil,
		_win_id = nil,
		_last_show_opts = {},
		_orientation = nil,
		_default_orientation = default_orientation,
		_title = nil,
	}
	setmetatable(new, self)
	return new
end

function BaseWindow:dispose()
	if self:is_visible() then
		self:hide()
	end
	if self._augroup then
		vim.api.nvim_del_augroup_by_id(self._augroup)
		self._augroup = nil
	end
	local buf = self:get_buf()
	if buf then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

function BaseWindow:redraw()
	error("Subclasses of BaseWindow must override BaseWindow:redraw()")
end

function BaseWindow:get_win()
	if self._win_id and vim.api.nvim_win_is_valid(self._win_id) then
		return self._win_id
	end
	return nil
end

function BaseWindow:get_buf()
	if self._buf_id and vim.api.nvim_buf_is_valid(self._buf_id) then
		return self._buf_id
	end
	return nil
end

function BaseWindow:get_orientation()
	return self._orientation
end

function BaseWindow:is_visible()
	return self:get_win() ~= nil
end

function BaseWindow:has_buffer()
	return self:get_buf() ~= nil
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
	opts = opts or self._last_show_opts
	local buf = self:get_buf()
	if not buf then
		buf = vim.api.nvim_create_buf(false, true)
		self._buf_id = buf
		self:_setup_buf()
		self:_setup_autocmds()
		self:redraw()
	end

	local orientation = opts.orientation or self._orientation or self._default_orientation
	local switched_layout = false

	local win = self:get_win()
	if win then
		if orientation == self._orientation then
			if vim.api.nvim_win_get_buf(win) ~= buf then
				vim.api.nvim_win_set_buf(win, buf)
			end
			vim.api.nvim_set_current_win(win)
			return
		else
			vim.api.nvim_win_close(win, true)
			self._win_id = nil
			switched_layout = true
		end
	end

	if self.track_parent_window then
		self._parent_window = vim.api.nvim_get_current_win()
	end
	local origin_window = opts.origin
	if origin_window then
		if type(origin_window) ~= "number" then
			origin_window = origin_window --[[@as BaseWindow]]:get_win()
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
		local w = math.floor(vim.o.columns * (opts.float_width or 0.6))
		local h = math.floor(vim.o.lines * (opts.float_height or 0.6))
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
	self.on_visibility_change:dispatch(switched_layout and "layout" or "visible")
end

function BaseWindow:hide()
	local win = self:get_win()
	local was_closed = false
	if win then
		vim.api.nvim_win_close(win, true)
		was_closed = true
	end
	self._win_id = nil
	self._orientation = nil
	if was_closed then
		if self._parent_window and vim.api.nvim_win_is_valid(self._parent_window) then
			vim.api.nvim_set_current_win(self._parent_window)
		end
		self._parent_window = nil
		self.on_visibility_change:dispatch("hidden")
	end
end

function BaseWindow:scroll_to_bottom()
	local win = self:get_win()
	assert(win, "Scrolling requires the window to be visible")
	local line_count = vim.api.nvim_buf_line_count(self._buf_id)
	vim.api.nvim_win_set_cursor(win, { line_count, 0 })
end

function BaseWindow:_setup_buf()
	local buf = self:get_buf()
	assert(buf, "No buffer")
	self.on_buffer_setup:dispatch(buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].bufhidden = "wipe"
end

function BaseWindow:_setup_autocmds()
	local buf = self:get_buf()
	assert(buf)
	if self._augroup then
		vim.api.nvim_del_augroup_by_id(self._augroup)
		self._augroup = nil
	end
	self._augroup = vim.api.nvim_create_augroup("CodeAssistBaseWindow" .. buf, { clear = true })
	vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
		group = self._augroup,
		buffer = buf,
		callback = function()
			self:hide()
			self._buf_id = nil
			vim.api.nvim_del_augroup_by_id(self._augroup)
			self._augroup = nil
		end,
	})
end

return BaseWindow
