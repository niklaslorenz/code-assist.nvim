local Util = require("code-assist.util")
local TextOption = require("code-assist.options.text")
local EnumOption = require("code-assist.options.enum")
local Container = require("code-assist.options.container")

--- @class ca.chat-completion.options: ca.opt.Container
--- @field from_conversation fun(opts: ca.chat-completion.options, conv: ChatCompletionConversation): ca.chat-completion.options
--- @field apply fun(opts: ca.chat-completion.options, conv: ChatCompletionConversation)
--- @field model ca.opt.Enum
--- @field system_message ca.opt.Text
--- @field reasoning_effort ca.opt.Enum
local Options = {}
Options.__index = Options
setmetatable(Options, Container)

function Options:from_conversation(conv)
	local models = { "default" }
	for i, name in ipairs(Util.get_available_model_names()) do
		models[i + 1] = name
	end
	local model = EnumOption:new("Model", models, conv.model or "default")
	local system_message =
			TextOption:new("System Message", conv:get_system_message() or Util.get_default_system_message())
	local reasoning_effort = EnumOption:new("Reasoning Effort", { "default", "low", "medium", "high" }, "default")

	--- @type ca.opt.Option[]
	local elements = {
		model,
		system_message,
		reasoning_effort,
	}

	local new = Container.new(self, "Conversation Options", elements, true) --[[@as ca.chat-completion.options]]
	new.model = model
	new.system_message = system_message
	new.reasoning_effort = reasoning_effort
	return new
end

function Options:apply(conv)
	local model = self.model:get_value()
	conv.model = model == "default" and Util.get_default_model_name() or model
	conv:replace_system_message(self.system_message:get_value())
	--- @type string?
	local re = self.reasoning_effort:get_value()
	if re == "default" then
		re = nil
	end
	conv.reasoning_effort = re
end

return Options
