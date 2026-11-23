local findJsonMediaType = require("./findJsonMediaType")
local formatKey = require("./formatKey")
local makeOptional = require("./makeOptional")
local quote = require("./quote")
local renderDocComment = require("./renderDocComment")
local renderType = require("./renderType")
local resolveRef = require("./resolveRef")
local toPascalCase = require("./toPascalCase")
local types = require("./types")

type MediaType = types.MediaType
type Operation = types.Operation
type Parameter = types.Parameter
type RequestBody = types.RequestBody
type Response = types.Response
type Schema = types.Schema
type TypeContext = types.TypeContext

-- The `send` field each parameter location goes in, and the order they're
-- written in.
local PARAM_LOCATIONS: { [string]: string } = {
	path = "pathParams",
	query = "query",
	header = "headers",
	cookie = "cookies",
}
local PARAM_FIELDS = {
	"pathParams",
	"query",
	"headers",
	"cookies",
}

local function resolveSchema(schema: Schema?, context: TypeContext): Schema?
	if schema and schema["$ref"] then
		return resolveRef(context.spec, schema["$ref"]) :: Schema
	end
	return schema
end

--[[
	Renders the expression `send` gets for one parameter. `accessor` is how the
	generated function reads its value, such as `args.ids`.

	OpenAPI's `style` and `explode` say how an array goes on the wire. By
	default a query array repeats its key, as in `ids=1&ids=2`, which `send`
	does itself. Headers, and query or cookie parameters with `explode` set to
	false, join the values with commas instead, which `runtime.formatList`
	does. Anything else is rejected so a client never sends it wrong: objects,
	styles other than the default such as `pipeDelimited`, path arrays, and
	cookie arrays that repeat their name.
]]
local function renderParamValue(parameter: Parameter, accessor: string, context: TypeContext): string
	local location = parameter["in"]
	local label = `{location} parameter '{parameter.name}'`
	local schema: Schema = resolveSchema(parameter.schema, context) or {}

	if schema.type == "object" or schema.properties then
		error(`{label} is an object, which isn't supported`, 0)
	end

	local defaultStyle = if location == "query" or location == "cookie" then "form" else "simple"
	local style = parameter.style or defaultStyle
	if style ~= defaultStyle then
		error(`{label} uses style '{style}', which isn't supported`, 0)
	end

	if schema.type ~= "array" then
		return accessor
	end

	local explode = if parameter.explode == nil then style == "form" else parameter.explode
	if location == "query" and explode then
		return accessor
	elseif location == "path" or (location == "cookie" and explode) then
		error(`{label} is an array sent as {style}, which isn't supported`, 0)
	end
	return `runtime.formatList({accessor})`
end

--[[
	Renders the body field's type and the `body` expression passed to `send`,
	plus whether the type needs parentheses before `?` is added. `content` is
	the request body's media types, keyed by content type. `bodyAccessor` is
	how the generated function reads the body, such as `args.body`. The caller
	guards an optional body, so this assumes it's set.
]]
local function renderBody(
	content: { [string]: MediaType },
	context: TypeContext,
	bodyAccessor: string
): (string?, string?, boolean)
	local contentType, mediaType = findJsonMediaType(content)
	if contentType and mediaType then
		local typeText, isCompound = renderType(mediaType.schema, context, 1)
		local expression =
			`\{\n\t\t\tkind = "json",\n\t\t\tcontentType = {quote(contentType)},\n\t\t\tvalue = {bodyAccessor},\n\t\t}`
		return typeText, expression, isCompound
	end

	local multipart = content["multipart/form-data"]
	if multipart then
		local schema: Schema = resolveSchema(multipart.schema, context) or {}
		local properties = schema.properties or {}
		local required = schema.required or {}
		local encodings = multipart.encoding or {}

		local names: { string } = {}
		for name in properties do
			table.insert(names, name)
		end
		table.sort(names)

		local typeLines: { string } = {}
		local fieldLines: { string } = {}
		for _, name in names do
			local property = properties[name]
			local resolved: Schema = resolveSchema(property, context) or {}
			local encodingContentType: string? = if encodings[name] then encodings[name].contentType else nil

			local encoding: string
			local typeText: string
			local isCompound: boolean
			if resolved.format == "binary" then
				encoding, typeText, isCompound = "file", "runtime.File", false
			else
				typeText, isCompound = renderType(property, context, 2)
				local isStructured = resolved.type == "object"
					or resolved.type == "array"
					or resolved.allOf ~= nil
					or resolved.oneOf ~= nil
					or resolved.anyOf ~= nil
					or resolved.properties ~= nil
				local isJsonType = if encodingContentType then encodingContentType:match("[/+]json$") ~= nil else false
				encoding = if isJsonType or isStructured then "json" else "text"
			end

			--[[
				A part's declared content type is sent with it, unless it's a list
				or wildcard such as `image/png, image/jpeg`, which only says what the
				server accepts. A file part sends the `File`'s own content type, and
				a JSON part already defaults to `application/json`.
			]]
			local isConcrete = if encodingContentType then encodingContentType:find("[,*]") == nil else false
			local isDefault = encoding == "json" and encodingContentType == "application/json"
			local contentTypeField = if encoding ~= "file"
					and isConcrete
					and not isDefault
				then ` contentType = {quote(encodingContentType :: string)},`
				else ""

			local fieldType = if table.find(required, name) then typeText else makeOptional(typeText, isCompound)
			table.insert(
				typeLines,
				renderDocComment(property.description, "\t\t") .. `\t\t{formatKey(name)}: {fieldType},`
			)
			table.insert(
				fieldLines,
				`\t\t\t\t\{ name = {quote(name)}, encoding = runtime.MultipartEncoding.{toPascalCase(encoding)},{contentTypeField} value = {bodyAccessor}[{quote(
					name
				)}] },`
			)
		end

		local typeText = `\{\n{table.concat(typeLines, "\n")}\n\t}`
		local expression =
			`\{\n\t\t\tkind = "multipart",\n\t\t\tfields = \{\n{table.concat(fieldLines, "\n")}\n\t\t\t},\n\t\t}`
		return typeText, expression, false
	end

	local rawContentType = next(content)
	if rawContentType then
		local expression =
			`\{\n\t\t\tkind = "raw",\n\t\t\tcontentType = {quote(rawContentType)},\n\t\t\tcontent = {bodyAccessor},\n\t\t}`
		return "string", expression, false
	end

	return nil, nil, false
end

-- Picks the success response and works out how `send` should read its body.
-- The lowest 2xx status wins, and `default` is used only when there's no 2xx
-- status at all.
local function renderResponse(operation: Operation, context: TypeContext): (string, string?)
	local responses = operation.object.responses or {}
	local statuses: { string } = {}
	for status in responses do
		if status:sub(1, 1) == "2" then
			table.insert(statuses, status)
		end
	end
	table.sort(statuses)

	local response = responses[statuses[1] or "default"]
	if response and response["$ref"] then
		response = resolveRef(context.spec, response["$ref"]) :: Response
	end
	local content: { [string]: MediaType }? = if response then response.content else nil
	if content == nil or next(content) == nil then
		return "none", nil
	end

	local _, mediaType = findJsonMediaType(content)
	if mediaType then
		local returnType = renderType(mediaType.schema, context, 0)
		return "json", returnType
	end
	return "text", "string"
end

-- Renders one operation as a params type and a function that sends it.
local function renderOperation(operation: Operation, context: TypeContext): string
	local paramsTypeName = toPascalCase(operation.name) .. "Params"

	local parameters = operation.object.parameters or {}

	--[[
		Parameters and the request body share one params table, so each needs a
		key of its own there. A name used in two locations, such as an `id` in
		both the path and the query, keeps the bare name for the first and adds
		the location to the rest, as in `idQuery`. The body is `body`, or
		`requestBody` when a parameter already took `body`.
	]]
	local isKeyTaken: { [string]: boolean } = {}
	local function claimKey(base: string): string
		local key = base
		local suffix = 2
		while isKeyTaken[key] do
			key = `{base}{suffix}`
			suffix += 1
		end
		isKeyTaken[key] = true
		return key
	end

	local typeLines: { string } = {}
	local groups: { [string]: { string } } = {}
	local hasRequired = false
	local isNameSeen: { [string]: boolean } = {}

	for _, parameter in parameters do
		local field = PARAM_LOCATIONS[parameter["in"]]
		if field == nil then
			continue
		end

		local key = if isNameSeen[parameter.name]
			then claimKey(parameter.name .. toPascalCase(parameter["in"]))
			else claimKey(parameter.name)
		isNameSeen[parameter.name] = true

		-- A path can't be built without its parameters, so they're required even
		-- when a document leaves off `required`.
		local isRequired = parameter["in"] == "path" or parameter.required == true
		hasRequired = hasRequired or isRequired
		local typeText, isCompound = renderType(parameter.schema, context, 1)
		local fieldType = if isRequired then typeText else makeOptional(typeText, isCompound)
		table.insert(typeLines, renderDocComment(parameter.description, "\t") .. `\t{formatKey(key)}: {fieldType},`)

		local accessor = if formatKey(key) == key then `args.{key}` else `args[{quote(key)}]`
		groups[field] = groups[field] or {}
		table.insert(
			groups[field],
			`\t\t\t{formatKey(parameter.name)} = {renderParamValue(parameter, accessor, context)},`
		)
	end

	local requestBody = operation.object.requestBody
	if requestBody and requestBody["$ref"] then
		requestBody = resolveRef(context.spec, requestBody["$ref"]) :: RequestBody
	end

	local bodyType: string?
	local bodyExpression: string?
	if requestBody and requestBody.content then
		local bodyKey = if isKeyTaken.body then claimKey("requestBody") else claimKey("body")
		local isRequired = requestBody.required == true
		local bodyAccessor = `args.{bodyKey}`
		local isCompound: boolean
		bodyType, bodyExpression, isCompound = renderBody(requestBody.content, context, bodyAccessor)
		if bodyExpression and not isRequired then
			bodyExpression = `if {bodyAccessor} == nil then nil else {bodyExpression}`
		end
		if bodyType then
			hasRequired = hasRequired or isRequired
			local fieldType = if isRequired then bodyType else makeOptional(bodyType, isCompound)
			table.insert(typeLines, renderDocComment(requestBody.description, "\t") .. `\t{bodyKey}: {fieldType},`)
		end
	end

	local responseKind, returnType = renderResponse(operation, context)

	-- Descriptions often open by repeating the summary, so the summary is only
	-- kept when it adds something.
	local summaryParts: { string } = {}
	local summary = if operation.object.summary then operation.object.summary:gsub("^%s+", ""):gsub("%s+$", "") else nil
	local isSummaryRepeated = operation.object.description ~= nil
		and operation.object.description:sub(1, #(summary or "")) == summary
	if summary and not isSummaryRepeated then
		table.insert(summaryParts, summary)
	end
	if operation.object.description then
		table.insert(summaryParts, operation.object.description)
	end
	if operation.object.deprecated then
		table.insert(summaryParts, "Deprecated.")
	end
	if operation.object.externalDocs and operation.object.externalDocs.url then
		table.insert(summaryParts, operation.object.externalDocs.url)
	end
	table.insert(summaryParts, `{operation.method} {operation.path}`)

	local chunks: { string } = {}
	local hasParams = #typeLines > 0
	if hasParams then
		table.insert(chunks, `export type {paramsTypeName} = \{\n{table.concat(typeLines, "\n")}\n}\n\n`)
	end

	table.insert(chunks, renderDocComment(table.concat(summaryParts, "\n\n"), ""))

	local signature = "client: runtime.Client"
	if hasParams then
		signature ..= if hasRequired then `, args: {paramsTypeName}` else `, params: {paramsTypeName}?`
	end
	local returnAnnotation = if returnType then `: {returnType}` else ""
	table.insert(chunks, `local function {operation.name}({signature}){returnAnnotation}\n`)

	if hasParams and not hasRequired then
		table.insert(chunks, `\tlocal args: {paramsTypeName} = params or \{}\n`)
	end

	local fields: { string } = {
		`\t\tmethod = {quote(operation.method)},`,
		`\t\tpath = {quote(operation.path)},`,
	}
	for _, field in PARAM_FIELDS do
		local lines = groups[field]
		if lines then
			table.insert(fields, `\t\t{field} = \{\n{table.concat(lines, "\n")}\n\t\t},`)
		end
	end
	if bodyExpression then
		table.insert(fields, `\t\tbody = {bodyExpression},`)
	end
	table.insert(fields, `\t\tresponseKind = runtime.ResponseKind.{toPascalCase(responseKind)},`)

	local call = `runtime.send(client, \{\n{table.concat(fields, "\n")}\n\t})`
	if returnType then
		table.insert(chunks, `\treturn {call} :: {returnType}\n`)
	else
		table.insert(chunks, `\t{call}\n`)
	end
	table.insert(chunks, "end\n")

	return table.concat(chunks)
end

return renderOperation
