--- @meta ChatCompletionObjects

--- @class ChatCompletionResponseStatus
--- @field complete boolean
--- @field streamed boolean
--- @field chunks ChatCompletionChunk[]?
--- @field message Message?

--- @class ChatCompletionChunkToolCall
--- @field index integer
--- @field id string
--- @field name string
--- @field arguments string

--- @class ChatCompletionToolCall
--- @field index integer
--- @field id string
--- @field name string
--- @field arguments string

--- @class ChatCompletionDelta
--- @field content string?
--- @field refusal string?
--- @field role string?
--- @field tool_calls ChatCompletionChunkToolCall[]

--- @class ChatCompletionChunkChoice
--- @field index integer
--- @field finish_reason string?
--- @field delta ChatCompletionDelta?

--- @class ChatCompletionUsage
--- @field completion_tokens integer
--- @field prompt_tokens integer

--- @class ChatCompletionChunk
--- @field id string
--- @field choices ChatCompletionChunkChoice[]
--- @field created integer
--- @field model string
--- @field system_fingerprint string
--- @field usage ChatCompletionUsage?
