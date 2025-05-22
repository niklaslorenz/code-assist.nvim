--- @meta

--- @class MessageAttachment
--- @field file_id string
--- @field tools ("code_interpreter" | "file_search")[]

--- @class MessageContent
--- @field type "image_file" | "image_url" | "text" | "refusal"

--- @class MessageImageFile: MessageContent
--- @field type "image_file"
--- @field file_id string
--- @field details string

--- @class MessageImageUrl: MessageContent
--- @field type "image_url"
--- @field url string
--- @field details string

--- @class MessageTextAnnotation
--- @field type "file_citation" | "file_path"
--- @field end_index integer
--- @field file_id string
--- @field start_index integer
--- @field text string

--- @class MessageText: MessageContent
--- @field type "text"
--- @field content string
--- @field annotations MessageTextAnnotation[]

--- @class MessageRefusal: MessageContent
--- @field type "refusal"
--- @field refusal string

--- @class MessagePrototype
--- @field content string|MessageContent[]
--- @field role "user" | "assistant"
--- @field attachments MessageAttachment[]?
--- @field metadata table<string, string>
