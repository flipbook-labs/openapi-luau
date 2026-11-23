local formatParam = require("./formatParam")
local types = require("./types")

type File = types.File
type MultipartField = types.MultipartField
type ParamValue = types.ParamValue
type Transport = types.Transport

--[[
	Part headers come from field names, filenames, and content types the caller
	passes in. A line break in one would end the header early and let the rest
	of the value write headers of its own, so this function and
	`quoteHeaderValue` reject it rather than send it.
]]
local function checkContentType(contentType: string): string
	if contentType:find("[\r\n]") then
		error("multipart content type can't contain a line break", 0)
	end
	return contentType
end

-- Quotes a field name or filename for `Content-Disposition`, escaping its
-- quotes and backslashes and rejecting line breaks.
local function quoteHeaderValue(value: string, label: string): string
	if value:find("[\r\n]") then
		error(`multipart {label} can't contain a line break`, 0)
	end
	local escaped = value:gsub('[\\"]', "\\%0")
	return `"{escaped}"`
end

--[[
	Builds a `multipart/form-data` body and returns its `Content-Type` header
	value and the body. Fields left nil are skipped. Each part is separated by a
	random boundary string, which is regenerated until no part's content
	contains it.
]]
local function encodeMultipart(fields: { MultipartField }, transport: Transport): (string, string)
	local parts: { { headers: { string }, content: string } } = {}

	for _, field in fields do
		if field.value == nil then
			continue
		end

		local disposition = `Content-Disposition: form-data; name={quoteHeaderValue(field.name, "field name")}`
		if field.encoding == types.MultipartEncoding.File then
			local file = field.value :: File
			table.insert(parts, {
				headers = {
					`{disposition}; filename={quoteHeaderValue(file.filename, "filename")}`,
					`Content-Type: {checkContentType(file.contentType)}`,
				},
				content = file.content,
			})
		elseif field.encoding == types.MultipartEncoding.Json then
			table.insert(parts, {
				headers = {
					disposition,
					`Content-Type: {checkContentType(field.contentType or "application/json")}`,
				},
				content = transport.encodeJson(field.value),
			})
		else
			local headers = { disposition }
			if field.contentType then
				table.insert(headers, `Content-Type: {checkContentType(field.contentType)}`)
			end
			table.insert(parts, {
				headers = headers,
				content = formatParam(field.value :: ParamValue),
			})
		end
	end

	local boundary: string
	repeat
		boundary = string.format("openapi-luau-%08x%08x", math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
		local isUnique = true
		for _, part in parts do
			if part.content:find(boundary, 1, true) then
				isUnique = false
				break
			end
		end
	until isUnique

	local chunks: { string } = {}
	for _, part in parts do
		table.insert(chunks, `--{boundary}\r\n{table.concat(part.headers, "\r\n")}\r\n\r\n{part.content}\r\n`)
	end
	table.insert(chunks, `--{boundary}--\r\n`)

	return `multipart/form-data; boundary={boundary}`, table.concat(chunks)
end

return encodeMultipart
