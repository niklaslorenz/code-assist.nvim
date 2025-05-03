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
--- @field private _content ContentWindowItemInternal[]
--- @field private _line_count integer
local ContentWindow = {}
ContentWindow.__index = ContentWindow
setmetatable(ContentWindow, BaseWindow)

function ContentWindow:new(orientation)
	--- @type ContentWindow
	local win = BaseWindow.new(self, orientation) --[[@as ContentWindow]]
	win._content = {}
	win._line_count = 0
	local buf = win:get_buf()
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buftype = "nofile"
	return win
end

function ContentWindow:item_count()
	return #self._content
end

function ContentWindow:add_item(item)
	local buf = self:get_buf()
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
	local buf = self:get_buf()
	local item = self._content[#self._content]
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, item.start_line, item.end_line, true, {})
	vim.bo[buf].modifiable = false
	table.remove(self._content, #self._content)
	self._line_count = self._line_count - (item.end_line - item.start_line)
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count + 1)
end

--- Replace the last item in the window with another one.
--- # Preconditions:
--- - `:item_count() > 0`
--- @param item ContentWindowItem
function ContentWindow:replace_last_item(item)
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
	local buf = self:get_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, {})
	local line_counter = 0
	for _, item in ipairs(self._content) do
		local line_count = #item.content_lines
		item.start_line = line_counter
		item.end_line = line_counter + line_count
		vim.api.nvim_buf_set_lines(buf, item.start_line, item.end_line, true, item.content_lines)
		line_counter = line_counter + line_count
	end
	vim.bo[buf].modifiable = false
	self._line_count = line_counter
	assert(vim.api.nvim_buf_line_count(buf) == self._line_count)
end

function ContentWindow:clear()
	local buf = self:get_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, {})
	vim.bo[buf].modifiable = false
	self._content = {}
	self._line_count = 0
end

return ContentWindow
