local ContentWindow = require("code-assist.ui.content-window")
local InputWindow = require("code-assist.ui.input-window")
local Options = require("code-assist.options")

local Windows = {}
Windows.Chat = ContentWindow:new(Options.default_window_orientation)
Windows.ChatInput = InputWindow:new(Options.default_window_orientation)

return Windows
