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
type Schema = types.Schema
type TypeContext = types.TypeContext

local PARAM_LOCATIONS: { [string]: string } = {
	path = "pathParams",
	query = "query",
	header = "headers",
}

local function resolveSchema(schema: Schema?, context: TypeContext): Schema?
	if schema and schema["$ref"] then
		return resolveRef(context.spec, schema["$ref"]) :: Schema
	end
	return schema
end

-- Renders the body field's type and the `body` expression passed to `send`.
-- `bodyAccessor` is how the generated function reads the body, such as
-- `args.body`. The caller guards an optional body, so this assumes it's set.
local function renderBody(requestBody: RequestBody, context: TypeContext, bodyAccessor: string): (string?, string?)
	if requestBody["$ref"] then
		requestBody = resolveRef(context.spec, requestBody["$ref"]) :: RequestBody
	end
	local content = requestBody.content
	if content == nil then
		return nil, nil
	end

	local contentType, mediaType = findJsonMediaType(content)
	if contentType and mediaType then
		local typeText = renderType(mediaType.schema, context, 1)
		local expression =
			`\{\n\t\t\tkind = "json",\n\t\t\tcontentType = {quote(contentType)},\n\t\t\tvalue = {bodyAccessor},\n\t\t}`
		return typeText, expression
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
			local encodingContentType = if encodings[name] then encodings[name].contentType else nil

			local encoding: string
			local typeText: string
			local isCompound: boolean
			if property.format == "binary" then
				encoding, typeText, isCompound = "file", "runtime.File", false
			else
				typeText, isCompound = renderType(property, context, 2)
				local isStructured = resolved.type == "object"
					or resolved.type == "array"
					or resolved.allOf ~= nil
					or resolved.oneOf ~= nil
					or resolved.anyOf ~= nil
					or resolved.properties ~= nil
				encoding = if encodingContentType == "application/json" or isStructured then "json" else "text"
			end

			local fieldType = if table.find(required, name) then typeText else makeOptional(typeText, isCompound)
			table.insert(
				typeLines,
				renderDocComment(property.description, "\t\t") .. `\t\t{formatKey(name)}: {fieldType},`
			)
			table.insert(
				fieldLines,
				`\t\t\t\t\{ name = {quote(name)}, encoding = runtime.MultipartEncoding.{toPascalCase(encoding)}, value = {bodyAccessor}[{quote(
					name
				)}] },`
			)
		end

		local typeText = `\{\n{table.concat(typeLines, "\n")}\n\t}`
		local expression =
			`\{\n\t\t\tkind = "multipart",\n\t\t\tfields = \{\n{table.concat(fieldLines, "\n")}\n\t\t\t},\n\t\t}`
		return typeText, expression
	end

	local rawContentType = next(content)
	if rawContentType then
		local expression =
			`\{\n\t\t\tkind = "raw",\n\t\t\tcontentType = {quote(rawContentType)},\n\t\t\tcontent = {bodyAccessor},\n\t\t}`
		return "string", expression
	end

	return nil, nil
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
	local paramNames: { [string]: boolean } = {}
	for _, parameter in parameters do
		paramNames[parameter.name] = true
	end
	-- Parameters and the request body share one params table, so the body moves
	-- to `requestBody` when a parameter is already named `body`.
	local bodyKey = if paramNames.body then "requestBody" else "body"

	local typeLines: { string } = {}
	local groups: { [string]: { string } } = {}
	local hasRequired = false

	for _, parameter in parameters do
		local field = PARAM_LOCATIONS[parameter["in"]]
		if field == nil then
			continue
		end

		-- A path can't be built without its parameters, so they're required even
		-- when a document leaves off `required`.
		local isRequired = parameter["in"] == "path" or parameter.required == true
		hasRequired = hasRequired or isRequired
		local typeText, isCompound = renderType(parameter.schema, context, 1)
		local fieldType = if isRequired then typeText else makeOptional(typeText, isCompound)
		table.insert(
			typeLines,
			renderDocComment(parameter.description, "\t") .. `\t{formatKey(parameter.name)}: {fieldType},`
		)

		local accessor = if formatKey(parameter.name) == parameter.name
			then `args.{parameter.name}`
			else `args[{quote(parameter.name)}]`
		groups[field] = groups[field] or {}
		table.insert(groups[field], `\t\t\t{formatKey(parameter.name)} = {accessor},`)
	end

	local bodyType: string?
	local bodyExpression: string?
	if operation.object.requestBody then
		local isRequired = operation.object.requestBody.required == true
		local bodyAccessor = `args.{bodyKey}`
		bodyType, bodyExpression = renderBody(operation.object.requestBody, context, bodyAccessor)
		if bodyExpression and not isRequired then
			bodyExpression = `if {bodyAccessor} == nil then nil else {bodyExpression}`
		end
		if bodyType then
			hasRequired = hasRequired or isRequired
			local fieldType = if isRequired then bodyType else makeOptional(bodyType, false)
			table.insert(
				typeLines,
				renderDocComment(operation.object.requestBody.description, "\t") .. `\t{bodyKey}: {fieldType},`
			)
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
	for _, field in { "pathParams", "query", "headers" } do
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
