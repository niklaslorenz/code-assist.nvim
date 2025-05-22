local AssistantCommands = {}
local ListWindow = require("code-assist.ui.list-window")
local Assistant = require("code-assist.assistant.assistant")

local function assistantListCommand(opts)
  --- @type number
  local num_elements
  if opts.nargs == 1 then
    num_elements = opts.args
  else
    num_elements = 20
  end
  local assistants = Assistant:list({
    limit = num_elements,
    order = "desc",
  })
  local display = ListWindow:new("float", "Assistants (loading)")
  display.on_visibility_change:subscribe(function(event)
    if event == "hidden" then
      display:dispose()
    end
  end)
  assistants.on_complete:subscribe(function(assistant_list)
    --- @cast assistant_list Assistant[]
    local names = {}
    for i, assistant in ipairs(assistant_list) do
      names[i] = assistant.name
    end
    display:set_content(names)
    display:set_title("Assistants")
  end)
end

function AssistantCommands.setup()
  vim.api.nvim_create_user_command("AssistantList", assistantListCommand, { nargs = "?" })
end

return AssistantCommands
