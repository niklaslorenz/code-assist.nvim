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
--- @field new fun(win: ContentWindow, orientation: WindowOrientation?): ContentWindow
--- @field item_count fun(win: ContentWindow): integer
--- @field add_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field remove_last_item fun(win: ContentWindow)
--- @field replace_last_item fun(win: ContentWindow, item: ContentWindowItem)
--- @field append_to_last_item fun(win: ContentWindow, content: string)
--- @field refresh fun(win: ContentWindow)
--- @field clear fun(win: ContentWindow)
--- @field scroll_to_previous_item fun(win: ContentWindow, begin: boolean)
--- @field scroll_to_next_item fun(win: ContentWindow, begin: boolean)
--- @field set_filter fun(win: ContentWindow, channel: string, include: boolean)
--- @field get_filters fun(win: ContentWindow): table<string, boolean>
--- @field private _find_item_index fun(win: ContentWindow, line: integer): integer
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
	local buf = win:get_buf()
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buftype = "nofile"
	return win
end

function ContentWindow:total_item_count()
	return #self._raw_items
end

function ContentWindow:displayed_item_count()
	return #self._content
end

function ContentWindow:add_item(item)
	local buf = self:get_buf()
	table.insert(self._raw_items, item)
	local is_included = not self._channel_filter[item.channel]
	if not is_included then
		return
	end
	local lines = vim.split(item.content, "\n")
	local start_line
	if #self._content ~= 0 then
		start_line = self._content[#self._content].end_line
	else
		start_line = 0
	end
	assert(vim.api.nvim_buf_line_count(self:get_buf()) == start_line + 1)
	local end_line = start_line + #lines
	--- @type ContentWindowItemInternal
	local wrapper = {
		content_lines = lines,
		channel = item.channel,
		start_line = start_line,
		end_line = end_line,
	}
	table.insert(self._content, wrapper)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, start_line, start_line, true, lines)
	vim.bo[buf].modifiable = false
	self._line_count = self._line_count + #lines
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

function ContentWindow:remove_last_item()
	assert(#self._content > 0)
	local raw_item = self._raw_items[#self._raw_items]
	table.remove(self._raw_items, #self._raw_items)
	local is_included = not self._channel_filter[raw_item.channel]
	if not is_included then
		return
	end
	local buf = self:get_buf()
	local item = self._content[#self._content]
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, item.start_line, item.end_line, true, {})
	vim.bo[buf].modifiable = false
	table.remove(self._content, #self._content)
	self._line_count = self._line_count - (item.end_line - item.start_line)
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

--- # Preconditions:
--- - `:item_count() > 0`
--- @param item ContentWindowItem
function ContentWindow:replace_last_item(item)
	local raw_item = self._raw_items[#self._raw_items]
	raw_item.channel = item.channel
	raw_item.content = item.content
	local is_included = not self._channel_filter[raw_item.channel]
	if not is_included then
		return
	end
	assert(#self._content > 0)
	local buf = self:get_buf()
	local wrapper = self._content[#self._content]
	local old_line_count = wrapper.end_line - wrapper.start_line
	local new_content_lines = vim.split(item.content, "\n")
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, wrapper.start_line, wrapper.end_line, true, new_content_lines)
	vim.bo[buf].modifiable = false
	wrapper.content_lines = new_content_lines
	wrapper.end_line = wrapper.start_line + #new_content_lines
	wrapper.channel = item.channel
	self._line_count = self._line_count - old_line_count + #new_content_lines
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

function ContentWindow:append_to_last_item(content)
	local raw_item = self._raw_items[#self._raw_items]
	raw_item.content = raw_item.content .. content
	local is_included = not self._channel_filter[raw_item.channel]
	if not is_included then
		return
	end
	assert(#self._content > 0)
	local buf = self:get_buf()
	local new_content_lines = vim.split(content, "\n")
	local item = self._content[#self._content]
	local last_line = item.content_lines[#item.content_lines]
	local new_last_line = last_line .. new_content_lines[1]
	item.content_lines[#item.content_lines] = new_last_line
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, item.end_line - 1, item.end_line, true, { new_last_line })
	if #new_content_lines > 1 then
		local additional_lines = {}
		for i, line in ipairs(new_content_lines) do
			if i > 1 then
				table.insert(additional_lines, line)
				table.insert(item.content_lines, line)
			end
		end
		vim.api.nvim_buf_set_lines(buf, item.end_line, item.end_line, true, additional_lines)
		item.end_line = item.end_line + #additional_lines
		self._line_count = self._line_count + #additional_lines
	end
	vim.bo[buf].modifiable = false
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

function ContentWindow:refresh()
	self._content = {}
	for _, item in ipairs(self._raw_items) do
		if not self._channel_filter[item.channel] then
			--- @type ContentWindowItemInternal
			local content_item = {
				content_lines = vim.split(item.content, "\n"),
				channel = item.channel,
				start_line = 0,
				end_line = 0,
			}
			table.insert(self._content, content_item)
		end
	end
	local buf = self:get_buf()
	vim.bo[buf].modifiable = true
	local line_counter = 0
	local all_lines = {}
	for _, item in ipairs(self._content) do
		local line_count = #item.content_lines
		item.start_line = line_counter
		item.end_line = line_counter + line_count
		for _, line in ipairs(item.content_lines) do
			table.insert(all_lines, line)
		end
		line_counter = line_counter + line_count
	end
	vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf) - 1, true, all_lines)
	vim.bo[buf].modifiable = false
	self._line_count = line_counter
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

function ContentWindow:clear()
	local buf = self:get_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, {})
	vim.bo[buf].modifiable = false
	self._content = {}
	self._raw_items = {}
	self._line_count = 0
end

function ContentWindow:scroll_to_previous_item(begin)
	local win = self:get_win()
	assert(win)
	local current_line = vim.api.nvim_win_get_cursor(win)[1] - 1
	local item_index = self:_find_item_index(current_line)
	print("scroll previous")
	print("current line: " .. current_line)
	print("current item: " .. item_index)
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
	print("scroll next")
	print("current line: " .. current_line)
	print("current item: " .. item_index)
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

function ContentWindow:set_filter(channel, include)
	self._channel_filter[channel] = not include
	self:refresh()
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

return ContentWindow
