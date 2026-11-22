local test = require("@std/test")

local send = require("./send")
local types = require("./types")

type Client = types.Client
type HttpError = types.HttpError
type HttpRequest = types.HttpRequest
type HttpResponse = types.HttpResponse

-- A transport that records each request and answers with a fixed response.
-- Its JSON functions are stand-ins so the tests don't depend on a platform
-- encoder. They only handle the `{ assetId = <number> }` shape these tests use.
local function createRecordingClient(response: HttpResponse): (Client, { HttpRequest })
	local requests: { HttpRequest } = {}
	local client: Client = {
		baseUrl = "https://apis.example.com",
		headers = {
			["x-api-key"] = "test-key",
		},
		transport = {
			request = function(request)
				table.insert(requests, request)
				return response
			end,
			encodeJson = function(value)
				local object = value :: { assetId: number }
				return `\{"assetId":{string.format("%d", object.assetId)}}`
			end,
			decodeJson = function(text)
				local digits = assert(text:match("(%d+)"))
				return {
					assetId = tonumber(digits),
				}
			end,
		},
	}
	return client, requests
end

test.suite("send", function(suite)
	suite:case("builds the request from the client and operation", function(assert)
		local client, requests = createRecordingClient({ status = 200, headers = {}, body = "" })

		send(client, {
			method = "POST",
			path = "/assets/{assetId}",
			pathParams = {
				assetId = "5",
			},
			headers = {
				["x-request-id"] = 12,
			},
			body = {
				kind = "json",
				contentType = "application/json",
				value = {
					assetId = 42,
				},
			},
			responseKind = "none",
		})

		assert.eq(requests, {
			{
				url = "https://apis.example.com/assets/5",
				method = "POST",
				headers = {
					["x-api-key"] = "test-key",
					["x-request-id"] = "12",
					["Content-Type"] = "application/json",
				},
				body = '{"assetId":42}',
			},
		})
	end)

	suite:case("decodes a JSON response through the transport", function(assert)
		local client = createRecordingClient({ status = 200, headers = {}, body = '{"assetId":123456789012345}' })

		local result = send(client, {
			method = "GET",
			path = "/assets/1",
			responseKind = "json",
		})

		assert.eq(result, { assetId = 123456789012345 })
	end)

	suite:case("returns nil for an empty JSON response", function(assert)
		local client = createRecordingClient({ status = 200, headers = {}, body = "  " })

		local result = send(client, {
			method = "DELETE",
			path = "/assets/1",
			responseKind = "json",
		})

		assert.eq(result, nil)
	end)

	suite:case("raises an HttpError carrying the status for a non-2xx response", function(assert)
		local client = createRecordingClient({ status = 409, headers = {}, body = "locked" })

		local operation: types.Operation = {
			method = "POST",
			path = "/places/1/versions",
			responseKind = "none",
		}

		local ok, err = pcall(send, client, operation)

		assert.eq(ok, false)
		local httpError = err :: HttpError
		assert.eq(httpError.status, 409)
		assert.eq(httpError.body, "locked")
		assert.eq(tostring(err), "409 from POST https://apis.example.com/places/1/versions: locked")
	end)
end)
