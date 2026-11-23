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

	-- Cookie parameters share one `Cookie` header, sorted so the same call
	-- always sends the same header. Values are percent-encoded because a
	-- cookie value can't hold spaces, commas, or semicolons.
	if operation.cookies then
		local names: { string } = {}
		for name in operation.cookies do
			table.insert(names, name)
		end
		table.sort(names)

		local cookies: { string } = {}
		for _, name in names do
			table.insert(cookies, `{name}={percentEncode(formatParam(operation.cookies[name] :: ParamValue))}`)
		end
		if #cookies > 0 then
			headers.Cookie = table.concat(cookies, "; ")
		end
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
