local ListWindow = require("code-assist.ui.list-window")
local Util = require("code-assist.util")
local EventDispatcher = require("code-assist.event-dispatcher")
local ConversationIO = require("code-assist.conversations.io")

--- @alias ConversationSelectWindow.SelectEvent string

--- @class ConversationSelectWindow : ListWindow
--- @field new fun(win: ConversationSelectWindow, orientation: WindowOrientation?, header: string?, sorting: ConversationSorting, mode: "listed" | "project"?): ConversationSelectWindow
--- @field set_sorting fun(win: ConversationSelectWindow, sorting: ConversationSorting)
--- @field select_hovered fun(win: ConversationSelectWindow)
--- @field refresh fun(win: ConversationSelectWindow)
--- @field private _retrieve_content fun(win: ConversationSelectWindow): string[]
--- @field on_select EventDispatcher<ConversationSelectWindow.SelectEvent>
--- @field mode "listed" | "project"
--- @field private _sorting ConversationSorting
local ConversationSelectWindow = {}
ConversationSelectWindow.__index = ConversationSelectWindow
setmetatable(ConversationSelectWindow, ListWindow)

function ConversationSelectWindow:new(orientation, header, sorting, mode)
	local new = ListWindow.new(ConversationSelectWindow, orientation, header, {}) --[[@as ConversationSelectWindow]]
	new.on_select = EventDispatcher:new()
	new.mode = mode or "listed"
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
		self:set_content(self:_retrieve_content())
	end, "descending modification date", opts)
	Util.set_keymap("oa", function()
		self:set_content(self:_retrieve_content())
	end, "ascending modification date", opts)
	Util.set_keymap("on", function()
		self:set_content(self:_retrieve_content())
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
	Util.set_keymap("x", function()
		local item = self:get_hovered_item()
		if not item then
			return
		end
		vim.ui.input({ prompt = "Delete " .. item .. "?" }, function(input)
			if not input then
				return
			end
			if input == "y" or input == "yes" then
				local ok, reason
				if self.mode == "listed" then
					ok, reason = ConversationIO.delete_listed_conversation(item)
				elseif self.mode == "project" then
					ok, reason = ConversationIO.delete_project_conversation(item)
				else
					error("Unknown mode: " .. self.mode)
				end
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
			local ok, reason
			if self.mode == "listed" then
				ok, reason = ConversationIO.rename_listed_conversation(item, input)
			elseif self.mode == "project" then
				ok, reason = ConversationIO.rename_project_conversation(item, input)
			else
				error("Unknown mode: " .. self.mode)
			end
			if not ok then
				vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
			end
			self:refresh()
		end)
	end, "Rename", opts)
	Util.set_keymap("m", nil, "Move conversation")
	if self.mode == "listed" then
		Util.set_keymap("mp", function()
			local item = self:get_hovered_item()
			if not item then
				return
			end
			vim.ui.input({ prompt = "Move to Project Conversations?" }, function(input)
				if not input then
					return
				end
				if input == "yes" or input == "y" then
					local ok, reason = ConversationIO.change_to_project_conversation(item)
					if not ok then
						vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
					end
				end
			end)
		end, "Move to project conversations", opts)
	elseif self.mode == "project" then
		Util.set_keymap("ml", function()
			local item = self:get_hovered_item()
			if not item then
				return
			end
			vim.ui.input({ prompt = "Move to Listed Conversations?" }, function(input)
				if not input then
					return
				end
				if input == "yes" or input == "y" then
					local ok, reason = ConversationIO.change_to_listed_conversation(item)
					if not ok then
						vim.notify(reason or "Unknown error", vim.log.levels.ERROR)
					end
				end
			end)
		end, "Move to listed conversations", opts)
	end
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
	local content = self:_retrieve_content()
	self:set_content(content)
end

function ConversationSelectWindow:_retrieve_content()
	if self.mode == "project" then
		return ConversationIO.list_project_conversations(self._sorting)
	elseif self.mode == "listed" then
		return ConversationIO.list_listed_conversations(self._sorting)
	else
		error("Unknown mode: " .. self.mode)
	end
end

return ConversationSelectWindow
