local EventDispatcher = require("code-assist.event-dispatcher")
local Options = require("code-assist.options")

--- @class ContentWindowItemInternal
--- @field content_lines string[]
--- @field channel string
--- @field start_line integer 0-based inclusive
--- @field end_line integer 0-based exclusive

--- @class ContentWindow
--- @field get_win fun(win: ContentWindow): integer|nil
--- @field get_buf fun(win: ContentWindow): integer|nil
--- @field new fun(win: ContentWindow): ContentWindow
--- @field open fun(win: ContentWindow, orientation: WindowOrientation?, title: string?)
--- @field hide fun(win: ContentWindow)
--- @field add_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field refresh fun(win: ContentWindow)
--- @field clear fun(win: ContentWindow)
--- @field on_status_change EventDispatcher<WindowStatus>
--- @field private _content ContentWindowItemInternal[]
--- @field private _win_id integer|nil
--- @field private _buf_id integer
--- @field private _orientation WindowOrientation
--- @field private _line_count integer
local ContentWindow = {}
ContentWindow.__index = ContentWindow

function ContentWindow:get_win()
	if not self._win_id then
		return nil
	end
	if vim.api.nvim_win_is_valid(self._win_id) then
		return self._win_id
	else
		return nil
	end
end

function ContentWindow:get_buf()
	return self._buf_id
end

function ContentWindow:new()
	local new = {
		on_status_change = EventDispatcher:new(),
		_content = {},
		_win_id = nil,
		_buf_id = vim.api.nvim_create_buf(false, true),
		_orientation = Options.default_window_orientation,
		_line_count = 0,
	}
	setmetatable(new, self)
	return new
end

--- @param orientation WindowOrientation?
--- @param title string?
function ContentWindow:open(orientation, title)
	local win = self:get_win()
	if not orientation then
		orientation = self._orientation
	end
	if win then
		if orientation == self._orientation then
			return
		else
			self:hide()
		end
	end

	vim.bo[self._buf_id].filetype = "markdown"
	vim.bo[self._buf_id].modifiable = false
	vim.bo[self._buf_id].buftype = "nofile"
	vim.bo[self._buf_id].swapfile = false

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
		if title ~= nil then
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
			title = title,
			title_pos = title_pos,
		})
	end

	self._orientation = orientation
	self.on_status_change:dispatch("visible")
end

function ContentWindow:hide()
	local win = self:get_win()
	if not win then
		self._win_id = nil
		return
	end
	vim.api.nvim_win_close(win, true)
	self.on_status_change:dispatch("hidden")
end

--- @param item ContentWindowItem
function ContentWindow:add_item(item)
	local lines = vim.split(item.content, "\n")
	local start_line = self._content[#self._content].end_line
	assert(vim.api.nvim_buf_line_count(self._buf_id) == start_line)
	local end_line = start_line + #lines
	--- @type ContentWindowItemInternal
	local wrapper = {
		content_lines = lines,
		channel = item.channel,
		start_line = start_line,
		end_line = end_line,
	}
	table.insert(self._content, wrapper)
	vim.api.nvim_buf_set_lines(self._buf_id, start_line, start_line, true, lines)
	assert(vim.api.nvim_buf_line_count(self._buf_id) == end_line)
end

function ContentWindow:remove_last_item()
	assert(#self._content > 0)
	local item = self._content[#self._content]
	vim.api.nvim_buf_set_lines(self._buf_id, item.start_line, item.end_line, true, {})
	table.remove(self._content, #self._content)
	self._line_count = self._line_count - (item.end_line - item.start_line)
end

function ContentWindow:refresh()
	vim.api.nvim_buf_set_lines(self._buf_id, 0, vim.api.nvim_buf_line_count(self._buf_id), true, {})
	local line_counter = 0
	for _, item in ipairs(self._content) do
		local line_count = #item.content_lines
		item.start_line = line_counter
		item.end_line = line_counter + line_count
		vim.api.nvim_buf_set_lines(self._buf_id, item.start_line, item.end_line, true, item.content_lines)
		line_counter = line_counter + line_count
	end
	self._line_count = 0
end

function ContentWindow:clear()
	vim.api.nvim_buf_set_lines(self._buf_id, 0, vim.api.nvim_buf_line_count(self._buf_id), true, {})
	self._content = {}
	self._line_count = 0
end

return ContentWindow
