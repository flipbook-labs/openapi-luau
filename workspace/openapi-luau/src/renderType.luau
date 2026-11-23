local formatKey = require("./formatKey")
local makeOptional = require("./makeOptional")
local quote = require("./quote")
local renderDocComment = require("./renderDocComment")
local types = require("./types")

type Schema = types.Schema
type TypeContext = types.TypeContext

local COMPONENT_PREFIX = "#/components/schemas/"

local renderType: (schema: Schema?, context: TypeContext, depth: number) -> (string, boolean)

-- Wraps a compound type in parentheses so a trailing `?` or a surrounding
-- operator applies to the whole type.
local function group(text: string, isCompound: boolean): string
	return if isCompound then `({text})` else text
end

local function renderJoined(
	schemas: { Schema },
	operator: string,
	context: TypeContext,
	depth: number
): (string, boolean)
	if #schemas == 1 then
		return renderType(schemas[1], context, depth)
	end

	local parts: { string } = {}
	for _, schema in schemas do
		local text, isCompound = renderType(schema, context, depth)
		local grouped = group(text, isCompound)
		if not table.find(parts, grouped) then
			table.insert(parts, grouped)
		end
	end
	return table.concat(parts, ` {operator} `), #parts > 1
end

local function renderObject(schema: Schema, context: TypeContext, depth: number): string
	local indent = string.rep("\t", depth + 1)
	local lines: { string } = {}

	local properties = schema.properties or {}
	local names: { string } = {}
	for name in properties do
		table.insert(names, name)
	end
	table.sort(names)

	local required = schema.required or {}
	for _, name in names do
		local property = properties[name]
		local text, isCompound = renderType(property, context, depth + 1)
		local typeText = if table.find(required, name) then text else makeOptional(text, isCompound)
		table.insert(lines, renderDocComment(property.description, indent) .. `{indent}{formatKey(name)}: {typeText},`)
	end

	if typeof(schema.additionalProperties) == "table" then
		local text = renderType(schema.additionalProperties :: Schema, context, depth + 1)
		table.insert(lines, `{indent}[string]: {text},`)
	elseif schema.additionalProperties == true or #names == 0 then
		table.insert(lines, `{indent}[string]: unknown,`)
	end

	return `\{\n{table.concat(lines, "\n")}\n{string.rep("\t", depth)}}`
end

local function renderBaseType(schema: Schema, context: TypeContext, depth: number): (string, boolean)
	local ref = schema["$ref"]
	if ref then
		assert(ref:sub(1, #COMPONENT_PREFIX) == COMPONENT_PREFIX, `unsupported schema ref {ref}`)
		local name = ref:sub(#COMPONENT_PREFIX + 1)
		local typeName = context.typeNames[name]
		if typeName == nil then
			error(`unknown schema {ref}`, 0)
		end
		context.referenced[name] = true
		return context.typePrefix .. typeName, false
	end

	if schema.allOf then
		return renderJoined(schema.allOf, "&", context, depth)
	elseif schema.oneOf then
		return renderJoined(schema.oneOf, "|", context, depth)
	elseif schema.anyOf then
		return renderJoined(schema.anyOf, "|", context, depth)
	end

	if schema.enum and schema.type == "string" and #schema.enum > 0 then
		local values: { string } = {}
		for _, value in schema.enum do
			if typeof(value) == "string" then
				table.insert(values, quote(value))
			end
		end
		if #values > 0 then
			return table.concat(values, " | "), #values > 1
		end
	end

	if schema.type == "string" then
		return "string", false
	elseif schema.type == "integer" or schema.type == "number" then
		return "number", false
	elseif schema.type == "boolean" then
		return "boolean", false
	elseif schema.type == "array" then
		local itemText = renderType(schema.items, context, depth)
		return `\{ {itemText} }`, false
	elseif schema.type == "object" or schema.properties or schema.additionalProperties ~= nil then
		return renderObject(schema, context, depth), false
	end

	return "unknown", false
end

--[[
	Renders a schema as a Luau type expression. The second result says whether
	the type is a union or intersection, which callers parenthesize before
	combining it with another type. A nullable type already ends in `?`, so it
	reports false and `makeOptional` leaves it alone.
]]
function renderType(schema: Schema?, context: TypeContext, depth: number): (string, boolean)
	if schema == nil then
		return "unknown", false
	end

	local text, isCompound = renderBaseType(schema, context, depth)
	if schema.nullable and text ~= "unknown" then
		return makeOptional(text, isCompound), false
	end
	return text, isCompound
end

return renderType
