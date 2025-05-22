local BaseWindow = require("code-assist.ui.base-window")

--- @class ListWindow : BaseWindow
--- @field new fun(win: ListWindow, orientation: WindowOrientation?, header: string?, content: string[]|string?): ListWindow
--- @field set_content fun(win: ListWindow, content: string[]?)
--- @field set_sorting fun(win: ListWindow)
--- @field set_header fun(win: ListWindow, header: string?)
--- @field get_hovered_index fun(win: ListWindow): integer
--- @field get_hovered_item fun(win: ListWindow): string?
--- @field private _content string[]
--- @field private _header string?
--- @field private _header_line_count integer
local ListWindow = {}
ListWindow.__index = ListWindow
setmetatable(ListWindow, BaseWindow)

function ListWindow:new(orientation, header, content)
	--- @type ListWindow
	local new = BaseWindow.new(self, orientation) --[[@as ListWindow]]
	content = content or {}
	if type(content) == "string" then
		content = vim.split(content, "\n")
	end
	new._content = content
	new._header = header
	new._header_line_count = 0
	return new
end

function ListWindow:_setup_buf()
	local buf = self:get_buf()
	assert(buf)
	vim.bo[buf].modifiable = false
	vim.bo[buf].swapfile = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
end

function ListWindow:set_content(content)
	if type(content) == "string" then
		content = vim.split(content, "\n")
	end
	self._content = content
	if self:has_buffer() then
		self:redraw()
	end
end

function ListWindow:set_header(header)
	self._header = header
	if self:has_buffer() then
		self:redraw()
	end
end

function ListWindow:redraw()
	local buf = self:get_buf()
	assert(buf)
	local lines = {}
	if self._header then
		for _, line in pairs(vim.split(self._header, "\n")) do
			table.insert(lines, line)
		end
		self._header_line_count = #lines
	else
		self._header_line_count = 0
	end
	for _, entry in ipairs(self._content) do
		table.insert(lines, entry)
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
	vim.bo[buf].modifiable = false
end

function ListWindow:get_hovered_index()
	local win = self:get_win()
	assert(win)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local index = line - self._header_line_count
	if index > 0 and index <= #self._content then
		return index
	else
		return 0
	end
end

function ListWindow:get_hovered_item()
	local index = self:get_hovered_index()
	if index <= 0 then
		return nil
	end
	return self._content[index]
end

return ListWindow
