local BaseWindow = require("code-assist.ui.base-window")

--- @class ContentWindowItem
--- @field content string
--- @field channel string

--- @class ContentWindowItemInternal
--- @field content_lines string[]
--- @field channel string
--- @field start_line integer 0-based inclusive
--- @field end_line integer 0-based exclusive

--- @class ContentWindow: BaseWindow
--- Constructor
--- @field new fun(win: ContentWindow, orientation: WindowOrientation?): ContentWindow
--- Public Methods
--- @field item_count fun(win: ContentWindow): integer
--- @field add_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field remove_last_item fun(win: ContentWindow)
--- @field replace_last_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field append_to_last_item fun(win: ContentWindow, content: string)
--- @field clear fun(win: ContentWindow)
--- @field scroll_to_previous_item fun(win: ContentWindow, begin: boolean)
--- @field scroll_to_next_item fun(win: ContentWindow, begin: boolean)
--- @field set_filter fun(win: ContentWindow, channel: string, include: boolean, refresh: boolean?)
--- @field get_filters fun(win: ContentWindow): table<string, boolean>
--- @field refresh_content fun(win: ContentWindow)
--- Private Methods
--- @field private _find_item_index fun(win: ContentWindow, line: integer): integer
--- @field private _append_buffer_content fun(win: ContentWindow, content: string, channel: string?)
--- @field private _remove_buffer_content fun(win: ContentWindow, replacement: ContentWindowItem?)
--- Private Fields
--- @field private _raw_items ContentWindowItem[]
--- @field private _content ContentWindowItemInternal[]
--- @field private _line_count integer
--- @field private _channel_filter table<string, boolean>
local ContentWindow = {}
ContentWindow.__index = ContentWindow
setmetatable(ContentWindow, BaseWindow)

function ContentWindow:new(orientation)
	--- @type ContentWindow
	local win = BaseWindow.new(self, orientation) --[[@as ContentWindow]]
	win._raw_items = {}
	win._content = {}
	win._line_count = 0
	win._channel_filter = {}
	return win
end

function ContentWindow:_setup_buf()
	BaseWindow._setup_buf(self)
	local buf = self:get_buf()
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buftype = "nofile"
end

function ContentWindow:total_item_count()
	return #self._raw_items
end

function ContentWindow:displayed_item_count()
	return #self._content
end

function ContentWindow:add_item(item)
	table.insert(self._raw_items, item)
	local is_included = not self._channel_filter[item.channel]
	if is_included then
		self:_append_buffer_content(item.content, item.channel)
	end
end

function ContentWindow:append_to_last_item(content)
	assert(#self._content > 0)
	local item = self._raw_items[#self._raw_items]
	item.content = item.content .. content
	local is_included = not self._channel_filter[item.channel]
	if is_included then
		self:_append_buffer_content(content, nil)
	end
end

function ContentWindow:remove_last_item()
	assert(#self._content > 0)
	local raw_item = self._raw_items[#self._raw_items]
	table.remove(self._raw_items, #self._raw_items)
	local is_included = not self._channel_filter[raw_item.channel]
	if is_included then
		self:_remove_buffer_content(nil)
	end
end

--- # Preconditions:
--- - `:item_count() > 0`
function ContentWindow:replace_last_item(item)
	assert(#self._content > 0)
	local old_item = self._raw_items[#self._raw_items]
	local new_item = {
		channel = item.channel,
		content = item.content,
	}
	self._raw_items[#self._raw_items] = new_item
	local old_is_included = not self._channel_filter[old_item.channel]
	local new_is_included = not self._channel_filter[new_item.channel]
	if old_is_included then
		self:_remove_buffer_content(new_is_included and new_item or nil)
	elseif new_is_included then
		self:_append_buffer_content(new_item.content, new_item.channel)
	end
end

function ContentWindow:redraw()
	local buf = self:get_buf()
	assert(buf)
	local lines = {}
	for _, item in ipairs(self._content) do
		for _, line in ipairs(item.content_lines) do
			table.insert(lines, line)
		end
	end
	table.insert(lines, "")
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, lines)
	vim.bo[buf].modifiable = false
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

function ContentWindow:clear()
	self._content = {}
	self._raw_items = {}
	self._line_count = 0
	local buf = self:get_buf()
	if buf then
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, {})
		vim.bo[buf].modifiable = false
	end
end

function ContentWindow:scroll_to_previous_item(begin)
	local win = self:get_win()
	assert(win)
	local current_line = vim.api.nvim_win_get_cursor(win)[1] - 1
	local item_index = self:_find_item_index(current_line)
	if item_index == 0 then
		vim.notify("Invalid item index", vim.log.levels.ERROR)
		return
	elseif item_index == 1 then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	else
		local target_item = self._content[item_index - 1]
		local newline = begin and target_item.start_line or target_item.end_line
		vim.api.nvim_win_set_cursor(win, { newline + 1, 0 })
	end
end

function ContentWindow:scroll_to_next_item(begin)
	local win = self:get_win()
	assert(win)
	local current_line = vim.api.nvim_win_get_cursor(win)[1] - 1
	local item_index = self:_find_item_index(current_line)
	if item_index == 0 then
		return
	elseif item_index == #self._content then
		vim.api.nvim_win_set_cursor(win, { self._line_count + 1, 0 })
	else
		local target_item = self._content[item_index + 1]
		local newline = begin and target_item.start_line or target_item.end_line
		vim.api.nvim_win_set_cursor(win, { newline + 1, 0 })
	end
end

function ContentWindow:set_filter(channel, include, refresh)
	self._channel_filter[channel] = not include
	if refresh then
		ContentWindow:refresh_content()
	end
end

function ContentWindow:get_filters()
	--- @type table<string, boolean>
	local filters = {}
	for _, item in ipairs(self._raw_items) do
		if filters[item.channel] == nil then
			filters[item.channel] = self._channel_filter[item.channel] ~= true
		end
	end
	return filters
end

function ContentWindow:refresh_content()
	self._content = {}
	self._line_count = 0
	local buf = self:get_buf()
	assert(buf)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, {})
	vim.bo[buf].modifiable = false
	for _, item in ipairs(self._raw_items) do
		if not self._channel_filter[item.channel] then
			self:_append_buffer_content(item.content, item.channel)
		end
	end
	self:redraw()
end

function ContentWindow:_find_item_index(line)
	if #self._content == 0 then
		return 0
	end
	if line >= self._line_count then
		return #self._content
	end
	for i = #self._content, 1, -1 do
		local item = self._content[i]
		if item.start_line <= line then
			return i
		end
	end
	error("Should not be reached")
end

function ContentWindow:_append_buffer_content(content, channel)
	local content_lines = vim.split(content, "\n")
	--- @type integer
	if channel then
		--- @type ContentWindowItemInternal
		local wrapper = {
			content_lines = content_lines,
			channel = channel,
			start_line = self._line_count,
			end_line = self._line_count + #content_lines,
		}
		self._line_count = self._line_count + #content_lines
		table.insert(self._content, wrapper)
		local buf = self:get_buf()
		if buf then
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, wrapper.start_line, wrapper.start_line, true, content_lines)
			vim.bo[buf].modifiable = false
			assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
		end
	else
		local wrapper = self._content[#self._content]
		local old_end_line = wrapper.end_line
		local new_line = wrapper.content_lines[#wrapper.content_lines] .. content_lines[1]
		wrapper.content_lines[#wrapper.content_lines] = new_line
		wrapper.end_line = wrapper.end_line + #content_lines - 1
		self._line_count = self._line_count + #content_lines - 1
		content_lines[1] = new_line
		for i = 2, #content_lines do
			table.insert(wrapper.content_lines, content_lines[i])
		end
		local buf = self:get_buf()
		if buf then
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, old_end_line - 1, old_end_line, true, content_lines)
			vim.bo[buf].modifiable = false
			assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
		end
	end
end

function ContentWindow:_remove_buffer_content(replacement)
	local item = self._content[#self._content]
	table.remove(self._content, #self._content)
	self._line_count = self._line_count - #item.content_lines
	local replacement_lines = nil
	if replacement then
		replacement_lines = vim.split(replacement.content, "\n")
		--- @type ContentWindowItemInternal
		local replacement_item = {
			content_lines = replacement_lines,
			channel = replacement.channel,
			start_line = item.start_line,
			end_line = item.start_line + #replacement_lines,
		}
		table.insert(self._content, replacement_item)
		self._line_count = self._line_count + #replacement_lines
	end
	local buf = self:get_buf()
	if buf then
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, item.start_line, item.end_line, true, replacement_lines or {})
		vim.bo[buf].modifiable = false
		assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
	end
end

return ContentWindow
