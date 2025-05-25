--- @meta ChatCompletionObjects

--- @alias ChatCompletionRole "system"|"user"|"assistant"

--- @class ChatCompletionMessage
--- @field content string
--- @field role ChatCompletionRole

--- @class ChatCompletionToolCall
--- @field index integer,
--- @field id string,
--- @field name string,
--- @field arguments string,

--- @class ChatCompletion
--- @field finish_reason string
--- @field content string?
--- @field refusal string?
--- @field role ChatCompletionRole
--- @field tool_calls ChatCompletionToolCall[]
--- @field created integer
--- @field id string
--- @field model string
--- @field system_fingerprint string
--- @field usage { completion_tokens: integer, prompt_tokens: integer}?
