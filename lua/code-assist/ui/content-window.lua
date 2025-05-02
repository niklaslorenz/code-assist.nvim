local EventDispatcher = require("code-assist.event-dispatcher")
local Options = require("code-assist.options")

--- @class ContentWindowItemInternal
--- @field content_lines string[]
--- @field channel string
--- @field start_line integer 0-based inclusive
--- @field end_line integer 0-based exclusive

--- @class ContentWindow
--- @field get_win fun(win: ContentWindow): integer|nil
--- @field get_buf fun(win: ContentWindow): integer
--- @field new fun(win: ContentWindow): ContentWindow
--- @field is_visible fun(win: ContentWindow): boolean
--- @field item_count fun(win: ContentWindow): integer
--- @field open fun(win: ContentWindow, orientation: WindowOrientation?)
--- @field hide fun(win: ContentWindow)
--- @field add_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field remove_last_item fun(win: ContentWindow)
--- @field replace_last_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field append_to_last_item fun(win: ContentWindow, content: string)
--- @field refresh fun(win: ContentWindow)
--- @field clear fun(win: ContentWindow)
--- @field scroll_to_bottom fun(win: ContentWindow)
--- @field set_title fun(win: ContentWindow, title: string?)
--- @field increase_window_width fun(win: ContentWindow)
--- @field decrease_window_width fun(win: ContentWindow)
--- @field increase_window_height fun(win: ContentWindow)
--- @field decrease_window_height fun(win: ContentWindow)
--- @field on_status_change EventDispatcher<WindowStatus>
--- @field private _content ContentWindowItemInternal[]
--- @field private _win_id integer|nil
--- @field private _buf_id integer
--- @field private _orientation WindowOrientation
--- @field private _line_count integer
--- @field private _title string?
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

function ContentWindow:is_visible()
	return self:get_win() ~= nil
end

function ContentWindow:item_count()
	return #self._content
end

--- @param orientation WindowOrientation?
function ContentWindow:open(orientation)
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
	local start_line
	if #self._content ~= 0 then
		start_line = self._content[#self._content].end_line
	else
		start_line = 0
	end
	assert(vim.api.nvim_buf_line_count(self._buf_id) == start_line + 1)
	local end_line = start_line + #lines
	--- @type ContentWindowItemInternal
	local wrapper = {
		content_lines = lines,
		channel = item.channel,
		start_line = start_line,
		end_line = end_line,
	}
	table.insert(self._content, wrapper)
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, start_line, start_line, true, lines)
	vim.bo[self._buf_id].modifiable = false
	self._line_count = self._line_count + #lines
	assert(vim.api.nvim_buf_line_count(self._buf_id) == self._line_count + 1)
end

function ContentWindow:remove_last_item()
	assert(#self._content > 0)
	local item = self._content[#self._content]
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, item.start_line, item.end_line, true, {})
	vim.bo[self._buf_id].modifiable = false
	table.remove(self._content, #self._content)
	self._line_count = self._line_count - (item.end_line - item.start_line)
	assert(vim.api.nvim_buf_line_count(self._buf_id) == self._line_count + 1)
end

--- Replace the last item in the window with another one.
--- # Preconditions:
--- - `:item_count() > 0`
--- @param item ContentWindowItem
function ContentWindow:replace_last_item(item)
	assert(#self._content > 0)
	local wrapper = self._content[#self._content]
	local old_line_count = wrapper.end_line - wrapper.start_line
	local new_content_lines = vim.split(item.content, "\n")
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, wrapper.start_line, wrapper.end_line, true, new_content_lines)
	vim.bo[self._buf_id].modifiable = false
	wrapper.content_lines = new_content_lines
	wrapper.end_line = wrapper.start_line + #new_content_lines
	wrapper.channel = item.channel
	self._line_count = self._line_count - old_line_count + #new_content_lines
	assert(vim.api.nvim_buf_line_count(self._buf_id) == self._line_count + 1)
end

function ContentWindow:append_to_last_item(content)
	assert(#self._content > 0)
	local new_content_lines = vim.split(content, "\n")
	local item = self._content[#self._content]
	local last_line = item.content_lines[#item.content_lines]
	local new_last_line = last_line .. new_content_lines[1]
	item.content_lines[#item.content_lines] = new_last_line
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, item.end_line - 1, item.end_line, true, { new_last_line })
	if #new_content_lines > 1 then
		local additional_lines = {}
		for i, line in ipairs(new_content_lines) do
			if i > 1 then
				table.insert(additional_lines, line)
				table.insert(item.content_lines, line)
			end
		end
		vim.api.nvim_buf_set_lines(self._buf_id, item.end_line, item.end_line, true, additional_lines)
		item.end_line = item.end_line + #additional_lines
		self._line_count = self._line_count + #additional_lines
	end
	vim.bo[self._buf_id].modifiable = false
	assert(vim.api.nvim_buf_line_count(self._buf_id) == self._line_count + 1)
end

function ContentWindow:refresh()
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, 0, vim.api.nvim_buf_line_count(self._buf_id), true, {})
	local line_counter = 0
	for _, item in ipairs(self._content) do
		local line_count = #item.content_lines
		item.start_line = line_counter
		item.end_line = line_counter + line_count
		vim.api.nvim_buf_set_lines(self._buf_id, item.start_line, item.end_line, true, item.content_lines)
		line_counter = line_counter + line_count
	end
	vim.bo[self._buf_id].modifiable = false
	self._line_count = line_counter
	assert(vim.api.nvim_buf_line_count(self._buf_id) == self._line_count)
end

function ContentWindow:clear()
	vim.bo[self._buf_id].modifiable = true
	vim.api.nvim_buf_set_lines(self._buf_id, 0, vim.api.nvim_buf_line_count(self._buf_id), true, {})
	vim.bo[self._buf_id].modifiable = false
	self._content = {}
	self._line_count = 0
end

--- Scroll to the bottom to the buffer.
--- # Preconditions:
--- - `:is_visible()`
function ContentWindow:scroll_to_bottom()
	local win = self:get_win()
	assert(win)
	vim.api.nvim_win_set_cursor(win, { self._line_count, 0 })
end

function ContentWindow:set_title(title)
	self._title = title
	local win = self:get_win()
	if win and self._orientation == "float" then
		local config = vim.api.nvim_win_get_config(win)
		config.title = title
		config.title_pos = "center"
		vim.api.nvim_win_set_config(win, config)
	end
end

function ContentWindow:increase_window_width()
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

function ContentWindow:increase_window_height()
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

function ContentWindow:decrease_window_width()
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

function ContentWindow:decrease_window_height()
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

return ContentWindow
