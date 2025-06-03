local Util = require("code-assist.util")
local Checkbox = require("code-assist.options.checkbox")
local TextOption = require("code-assist.options.text")
local EnumOption = require("code-assist.options.enum")
local Container = require("code-assist.options.container")
local Windows = require("code-assist.ui.window-instances")

--- @class ca.chat-completion.options: ca.opt.Container
--- @field from_conversation fun(opts: ca.chat-completion.options, conv: ChatCompletionConversation): ca.chat-completion.options
--- @field apply fun(opts: ca.chat-completion.options, conv: ChatCompletionConversation)
--- Fields
--- @field agent ca.opt.Enum
--- @field channel_options ca.opt.Checkbox[]
--- @field channels string[]
local Options = {}
Options.__index = Options
setmetatable(Options, Container)

function Options:from_conversation(conv)
	local agents = { "default" }
	for i, name in ipairs(Util.get_agent_names()) do
		agents[i + 1] = name
	end
	local agent_option = EnumOption:new("Agents", agents, conv.agent or "default")

	local channel_options = {}
	local channels = {}
	for channel, included in pairs(Windows.Chat:get_filters()) do
		table.insert(channel_options, Checkbox:new(channel, included))
		table.insert(channels, channel)
	end
	local channel_container = Container:new("Filters", channel_options)

	--- @type ca.opt.Option[]
	local elements = {
		agent_option,
		channel_container,
	}

	local new = Container.new(self, "Conversation Options", elements, true) --[[@as ca.chat-completion.options]]
	new.agent = agent_option
	new.channel_options = channel_options
	new.channels = channels
	return new
end

function Options:apply(conv)
	local agent = self.agent:get_value()
	for _, option in ipairs(self.channel_options) do
		Windows.Chat:set_filter(option.name, option:get_value())
	end
	conv:set_agent(agent ~= "default" and agent or nil)
	Windows.Chat:refresh_content()
end

return Options
