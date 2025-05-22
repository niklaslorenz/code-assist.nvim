local BasicParser = {}

local Parsing = require("code-assist.assistant.interface.parsing")

--- @param data table?
--- @return MessageAttachment?
function BasicParser.parse_message_resources(data)
  if data == nil then
    return nil
  end
  --- @type MessageAttachment
  local attachment = {
    file_id = Parsing.try_get("file_id", "string", data),
    tools = Parsing.try_parse_array("tools", "string", data, function(x)
      return x.type
    end, true),
  }
  return attachment
end

--- @param data table?
--- @return MessageTextAnnotation?
function BasicParser.parse_message_text_annotation(data)
  if data == nil then
    return nil
  end
  local type = Parsing.try_get("type", "string", data)
  --- @type { file_id: string}
  local file_id_wrapper
  if type == "file_citation" then
    file_id_wrapper = Parsing.try_get("file_citation", "table", data)
  elseif type == "file_path" then
    file_id_wrapper = Parsing.try_get("file_path", "table", data)
  else
    error("Unknown text annotation type: " .. type)
  end
  --- @type MessageTextAnnotation
  local content = {
    type = type,
    end_index = Parsing.try_get_number("end_index", "integer", data),
    file_id = Parsing.try_get("file_id", "string", file_id_wrapper),
    start_index = Parsing.try_get_number("start_index", "integer", data),
    text = Parsing.try_get("text", "string", data),
  }
  return content
end

--- @param data table?
--- @return MessageContent?
function BasicParser.parse_message_content(data)
  if data == nil then
    return nil
  end
  local type = Parsing.try_get("type", "string", data)
  --- @type MessageContent
  local content
  if type == "image_file" then
    local image_file_wrapper = Parsing.try_get("image_file", "table", data)
    --- @type MessageImageFile
    content = {
      type = "image_file",
      file_id = Parsing.try_get("file_id", "string", image_file_wrapper),
      details = Parsing.try_get("details", "string", image_file_wrapper),
    }
  elseif type == "image_url" then
    local image_url_wrapper = Parsing.try_get("image_url", "table", data)
    --- @type MessageImageUrl
    content = {
      type = "image_url",
      url = Parsing.try_get("url", "string", image_url_wrapper),
      details = Parsing.try_get("details", "string", image_url_wrapper),
    }
  elseif type == "text" then
    local text_wrapper = Parsing.try_get("text", "table", data)
    --- @type MessageText
    content = {
      type = "text",
      content = Parsing.try_get("value", "string", text_wrapper),
      annotations = Parsing.try_parse_array(
        "annotations",
        "table",
        text_wrapper,
        BasicParser.parse_text_annotation,
        true
      ),
    }
  elseif type == "refusal" then
    --- @type MessageRefusal
    content = {
      type = "refusal",
      refusal = Parsing.try_get("refusal", "string", data),
    }
  else
    error("Unknown message content type: " .. type)
  end
  return content
end

--- @param data table?
--- @return AssistantToolResources?
function BasicParser.parse_tool_resources(data)
  if data == nil then
    return nil
  end

  local code_interpreter = Parsing.try_get("code_interpreter", "table", data)
  local file_search = Parsing.try_get("file_search", "table", data)

  local file_ids = Parsing.try_parse_optional_array("file_ids", "string", code_interpreter, function(x)
    return x
  end, true) or {}
  local vector_store_ids = Parsing.try_parse_optional_array("vector_store_ids", "string", file_search, function(x)
    return x
  end, true) or {}

  --- @type AssistantToolResources
  local resource = {
    code_interpreter_file_ids = file_ids,
    file_search_vector_store_ids = vector_store_ids,
  }
  return resource
end

return BasicParser
