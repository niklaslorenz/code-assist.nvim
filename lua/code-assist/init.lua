local M = {}

local has_plenary = pcall(require, "plenary")
if not has_plenary then
	error("plenary.nvim is required but not installed")
	return
end

local PluginOptions = require("code-assist.options")
local Control = require("code-assist.control.control")
local Keymaps = require("code-assist.control.keymaps")

function M.setup(opts)
	if opts then
		for k, v in pairs(opts) do
			if PluginOptions[k] then
				PluginOptions[k] = v
			end
		end
	end

	vim.api.nvim_set_hl(0, "ChatUser", { fg = PluginOptions.user_chat_color, bold = true })
	vim.api.nvim_set_hl(0, "ChatAssistant", { fg = PluginOptions.assistant_chat_color, bold = true })

	Control.setup()
	Keymaps.setup_global_keymaps()
end

return M
