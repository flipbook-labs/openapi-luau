local buildUrl = require("./buildUrl")
local encodeMultipart = require("./encodeMultipart")
local formatParam = require("./formatParam")
local percentEncode = require("./percentEncode")
local types = require("./types")

type Client = types.Client
type HttpError = types.HttpError
type Operation = types.Operation
type ParamValue = types.ParamValue

local HttpErrorMetatable = {
	__tostring = function(err: HttpError)
		return `{err.status} from {err.method} {err.url}: {err.body}`
	end,
}

-- Sends one operation through the client's transport. A response outside the
-- 2xx range raises an `HttpError`, which carries the status so callers can
-- handle specific failures.
local function send(client: Client, operation: Operation): unknown
	local url = buildUrl(client.baseUrl, operation.path, operation.pathParams, operation.query)

	local headers = table.clone(client.headers)
	if operation.headers then
		for name, value in operation.headers do
			headers[name] = formatParam(value)
		end
	end

	--[[
		Cookie parameters go in the `Cookie` header, alongside any cookies the
		client's headers already send, such as a session. A parameter replaces a
		client cookie with the same name and keeps its place. New ones follow in
		sorted order, so the same call always sends the same header. Values are
		percent-encoded because a cookie value can't hold spaces, commas, or
		semicolons. HTTP header names ignore case, so a client's `cookie` header
		is merged too and sent as `Cookie`.
	]]
	if operation.cookies and next(operation.cookies) then
		local cookies: { { name: string, value: string } } = {}
		for headerName, headerValue in table.clone(headers) do
			if headerName:lower() == "cookie" then
				headers[headerName] = nil
				for pair in headerValue:gmatch("[^;]+") do
					local name, value = pair:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
					if name and value then
						table.insert(cookies, { name = name, value = value })
					end
				end
			end
		end

		local names: { string } = {}
		for name in operation.cookies do
			table.insert(names, name)
		end
		table.sort(names)

		for _, name in names do
			local value = percentEncode(formatParam(operation.cookies[name] :: ParamValue))
			local existing: { name: string, value: string }? = nil
			for _, cookie in cookies do
				if cookie.name == name then
					existing = cookie
				end
			end
			if existing then
				existing.value = value
			else
				table.insert(cookies, { name = name, value = value })
			end
		end

		local pairsList: { string } = {}
		for _, cookie in cookies do
			table.insert(pairsList, `{cookie.name}={cookie.value}`)
		end
		headers.Cookie = table.concat(pairsList, "; ")
	end

	local body: string? = nil
	if operation.body then
		if operation.body.kind == "json" then
			headers["Content-Type"] = operation.body.contentType
			body = client.transport.encodeJson(operation.body.value)
		elseif operation.body.kind == "multipart" then
			local contentType, content = encodeMultipart(operation.body.fields, client.transport)
			headers["Content-Type"] = contentType
			body = content
		else
			headers["Content-Type"] = operation.body.contentType
			body = operation.body.content
		end
	end

	local response = client.transport.request({
		url = url,
		method = operation.method,
		headers = headers,
		body = body,
	})

	if response.status < 200 or response.status >= 300 then
		local err: HttpError = {
			method = operation.method,
			url = url,
			status = response.status,
			body = response.body,
		}
		error(setmetatable(err, HttpErrorMetatable), 0)
	end

	if operation.responseKind == types.ResponseKind.None then
		return nil
	elseif operation.responseKind == types.ResponseKind.Text then
		return response.body
	end

	if response.body:match("^%s*$") then
		return nil
	end

	return client.transport.decodeJson(response.body)
end

return send
