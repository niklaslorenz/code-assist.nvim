local M = {}

M.run = function(opts)
	-- parse args
	local args = {}
	for arg in string.gmatch(opts.args or "", "%S+") do
		table.insert(args, arg)
	end
	local mode, layout = args[1], args[2]
	-- if only one arg, treat it as layout
	if layout == nil then
		layout = mode
		mode = nil
	end
	-- determine flags
	local is_new = (mode == "n" or mode == "new")
	local is_select = (mode == "s" or mode == "select")
	-- determine orientation
	local orientation = "float"
	if layout == "h" or layout == "horizontal" then
		orientation = "horizontal"
	elseif layout == "v" or layout == "vertical" then
		orientation = "vertical"
	end
	local use_split = (orientation ~= "float")

	if is_select then
		-- selection UI opens and handles layout
		require("code-assist.ui").select_conversation({ split = use_split, orientation = orientation })
		return
	end

	-- load or create
	local name, msgs
	if is_new then
		name, msgs = require("code-assist.conversation-manager").new_conversation()
	else
		name, msgs = require("code-assist.conversation-manager").load_or_new()
	end

	require("code-assist.ui.chat-window").open(name, msgs, orientation)
end

M.setup = function()
	vim.api.nvim_create_user_command("Chat", M.run, {
		nargs = "*",
		complete = function(ArgLead)
			local opts = { "f", "h", "v", "n f", "n h", "n v", "s f", "s h", "s v" }
			return vim.tbl_filter(function(val)
				return vim.startswith(val, ArgLead)
			end, opts)
		end,
	})
end

return M
