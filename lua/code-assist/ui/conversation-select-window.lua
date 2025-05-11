local ListWindow = require("code-assist.ui.list-window")
local Util = require("code-assist.util")
local ConversationManager = require("code-assist.conversation-manager")
local EventDispatcher = require("code-assist.event-dispatcher")

--- @alias ConversationSelectWindow.SelectEvent string

--- @class ConversationSelectWindow : ListWindow
--- @field new fun(win: ConversationSelectWindow, orientation: WindowOrientation?, header: string?, path: string?, sorting: ConversationSorting): ConversationSelectWindow
--- @field set_sorting fun(win: ConversationSelectWindow, sorting: ConversationSorting)
--- @field select_hovered fun(win: ConversationSelectWindow)
--- @field refresh fun(win: ConversationSelectWindow)
--- @field on_select EventDispatcher<ConversationSelectWindow.SelectEvent>
--- @field private _path string?
--- @field private _sorting ConversationSorting
local ConversationSelectWindow = {}
ConversationSelectWindow.__index = ConversationSelectWindow
setmetatable(ConversationSelectWindow, ListWindow)

function ConversationSelectWindow:new(orientation, header, path, sorting)
	local new = ListWindow.new(ConversationSelectWindow, orientation, header, {}) --[[@as ConversationSelectWindow]]
	new.on_select = EventDispatcher:new()
	new._path = path
	new._sorting = sorting
	return new
end

function ConversationSelectWindow:_setup_buf()
	ListWindow._setup_buf(self)
	local buf = self:get_buf()
	assert(buf)
	--- @type vim.keymap.set.Opts
	local opts = { silent = true, noremap = true, buffer = buf }
	Util.set_keymap("o", nil, "Order items", opts)
	Util.set_keymap("od", function()
		self:set_content(ConversationManager.list_conversations("newest", self._path))
	end, "descending modification date", opts)
	Util.set_keymap("oa", function()
		self:set_content(ConversationManager.list_conversations("oldest", self._path))
	end, "ascending modification date", opts)
	Util.set_keymap("on", function()
		self:set_content(ConversationManager.list_conversations("name", self._path))
	end, "name", opts)
	Util.set_keymap("q", function()
		self:hide()
	end, "Close", opts)
	Util.set_keymap("<CR>", function()
		self:select_hovered()
	end, "Select", opts)
	Util.set_keymap("l", function()
		self:select_hovered()
	end, "Select", opts)
	Util.set_keymap("d", function()
		local item = self:get_hovered_item()
		if not item then
			return
		end
		vim.ui.input({ prompt = "Delete " .. item .. "?", default = "no" }, function(input)
			if not input then
				return
			end
			if input == "y" or input == "yes" then
				local ok, reason = ConversationManager.delete_conversation(item, self._path)
				if not ok then
					vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
				end
				self:refresh()
			end
		end)
	end, "Delete", opts)
	Util.set_keymap("r", function()
		local item = self:get_hovered_item()
		if not item then
			return
		end
		vim.ui.input({ prompt = "Rename", default = item }, function(input)
			if not input then
				return
			end
			local ok, reason = ConversationManager.rename_conversation(item, input)
			if not ok then
				vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
			end
			self:refresh()
		end)
	end, "Rename", opts)
	self:refresh()
end

function ConversationSelectWindow:set_sorting(sorting)
	self._sorting = sorting
	self:refresh()
end

function ConversationSelectWindow:select_hovered()
	local item = self:get_hovered_item()
	if item then
		self.on_select:dispatch(item)
	end
end

function ConversationSelectWindow:refresh()
	local content = ConversationManager.list_conversations(self._sorting, self._path)
	self:set_content(content)
	if self:has_buffer() then
		self:redraw()
	end
end

return ConversationSelectWindow
