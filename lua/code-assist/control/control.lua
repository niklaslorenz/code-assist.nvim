local Control = {}

local ChatWindowControl = require("code-assist.control.chat-window-control")
local ChatWindowInputControl = require("code-assist.control.chat-input-window-control")
local ConversationManagerControl = require("code-assist.control.conversation-manager-control")

function Control.setup()
  ChatWindowControl.setup()
  ChatWindowInputControl.setup()
  ConversationManagerControl.setup()
end

return Control
