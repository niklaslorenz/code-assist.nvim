--- Provides methods for parsing decoded json responses.
local Parsing = {}

--- Try to retrieve an optional named value of a data object.
--- @param name string
--- @param expected_type string
--- @param data any
--- @return unknown|nil
function Parsing.try_get_optional(name, expected_type, data)
	local value = data[name]
	if not value or value == vim.NIL then
		return nil
	end
	if type(value) ~= expected_type then
		error(
			"Invalid property type for property "
			.. name
			.. ": Expected "
			.. expected_type
			.. " but got "
			.. type(value)
		)
	end
	return value
end

--- Try to retrieve an named value of a data object.
--- @param name string
--- @param expected_type string
--- @param data any
--- @return unknown
function Parsing.try_get(name, expected_type, data)
	local value = Parsing.try_get_optional(name, expected_type, data)
	if not value then
		error("Invalid nil value for property: " .. name)
	end
	return value
end

--- Try to retrieve a numerical value of a given type.
--- @param name string
--- @param expected_type "integer"|"float"
--- @param data any
--- @return number
function Parsing.try_get_number(name, expected_type, data)
	local value = Parsing.try_get(name, "number", data)
	local actual_type = math.floor(value) == value and "integer" or "float"
	if actual_type ~= expected_type then
		error(
			"Invalid number type for property " .. name .. ": Expected " .. expected_type .. " but got " .. actual_type
		)
	end
	return value
end

function Parsing.try_parse_object(name, data, object_parser, allow_nil)
	local object_data
	if allow_nil then
		object_data = Parsing.try_get_optional(name, "table", data)
		if not object_data then
			return nil
		end
	else
		object_data = Parsing.try_get(name, "table", data)
	end
	return object_parser(object_data)
end

--- Try to parse an array of items.
--- @param name string The name of the array
--- @param expected_element_type string
--- @param data any
--- @param element_parser fun(element: unknown): unknown
--- @param allow_empty boolean
--- @param allow_nil boolean
--- @return unknown[] result
function Parsing.try_parse_array(name, expected_element_type, data, element_parser, allow_empty, allow_nil)
	local array_value
	if allow_nil then
		array_value = Parsing.try_get_optional(name, "table", data)
		if not array_value then
			return {}
		end
	else
		array_value = Parsing.try_get(name, "table", data)
	end
	if #array_value == 0 then
		if allow_empty then
			return {}
		end
		error("Array must not be empty: " .. name)
	end
	local parsed_array = {}
	for _, value in ipairs(array_value) do
		if type(value) ~= expected_element_type then
			error(
				"Invalid type for array element "
				.. name
				.. ": Expected "
				.. expected_element_type
				.. " but got "
				.. type(value)
			)
		end
		local parsed_value = element_parser(value)
		table.insert(parsed_array, parsed_value)
	end
	return parsed_array
end

return Parsing
