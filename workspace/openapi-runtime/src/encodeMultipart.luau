local formatParam = require("./formatParam")
local types = require("./types")

type File = types.File
type MultipartField = types.MultipartField
type ParamValue = types.ParamValue
type Transport = types.Transport

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

		if field.encoding == types.MultipartEncoding.File then
			local file = field.value :: File
			table.insert(parts, {
				headers = {
					`Content-Disposition: form-data; name="{field.name}"; filename="{file.filename}"`,
					`Content-Type: {file.contentType}`,
				},
				content = file.content,
			})
		elseif field.encoding == types.MultipartEncoding.Json then
			table.insert(parts, {
				headers = {
					`Content-Disposition: form-data; name="{field.name}"`,
					"Content-Type: application/json",
				},
				content = transport.encodeJson(field.value),
			})
		else
			table.insert(parts, {
				headers = {
					`Content-Disposition: form-data; name="{field.name}"`,
				},
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
