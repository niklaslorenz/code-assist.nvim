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

--- @class ChatCompletionChunkDelta
--- @field content string?
--- @field refusal string?
--- @field role string?
--- @field tool_calls ChatCompletionChunkToolCall[]

--- @class ChatCompletionChunkChoice
--- @field index integer
--- @field finish_reason string?
--- @field delta ChatCompletionChunkDelta

--- @class ChatCompletionChunk
--- @field id string
--- @field choices ChatCompletionChunkChoice[]
--- @field created integer
--- @field model string
--- @field system_fingerprint string
