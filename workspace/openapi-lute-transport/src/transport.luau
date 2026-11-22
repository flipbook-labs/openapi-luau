local json = require("@std/json")
local net = require("@std/net")

type HttpRequest = {
	url: string,
	method: string,
	headers: { [string]: string },
	body: string?,
}

type HttpResponse = {
	status: number,
	headers: { [string]: string },
	body: string,
}

local function request(httpRequest: HttpRequest): HttpResponse
	local response = net.request(httpRequest.url, {
		method = httpRequest.method,
		headers = httpRequest.headers,
		body = httpRequest.body,
	})
	return {
		status = response.status,
		headers = response.headers,
		body = response.body,
	}
end

local function encodeJson(value: unknown): string
	return json.serialize(value :: json.Value)
end

--[[
	`@std/json` decodes `null` as a `json.null` sentinel and tags each object
	with a marker key, which would show up when iterating a decoded table.
	Clients expect plain tables, so this turns `null` into `nil` and keeps only
	string and number keys.
]]
local function toPlainValue(value: unknown): unknown
	if value == (json.null :: unknown) then
		return nil
	elseif typeof(value) == "table" then
		local source = value :: { [unknown]: unknown }
		local result: { [unknown]: unknown } = {}
		for key, item in source do
			if typeof(key) == "string" or typeof(key) == "number" then
				result[key] = toPlainValue(item)
			end
		end
		return result
	end
	return value
end

local function decodeJson(text: string): unknown
	return toPlainValue(json.deserialize(text))
end

return {
	request = request,
	encodeJson = encodeJson,
	decodeJson = decodeJson,
}
