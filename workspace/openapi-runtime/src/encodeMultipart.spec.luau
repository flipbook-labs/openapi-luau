local test = require("@std/test")

local encodeMultipart = require("./encodeMultipart")
local types = require("./types")

type Transport = types.Transport

local transport: Transport = {
	request = function()
		error("not used")
	end,
	encodeJson = function(value)
		local object = value :: { displayName: string }
		return `\{"displayName":"{object.displayName}"}`
	end,
	decodeJson = function()
		error("not used")
	end,
}

test.suite("encodeMultipart", function(suite)
	suite:case("writes JSON, file, and text parts and skips nil fields", function(assert)
		local contentType, body = encodeMultipart({
			{ name = "request", encoding = "json", value = { displayName = "Sword" } },
			{
				name = "fileContent",
				encoding = "file",
				value = { filename = "sword.rbxm", contentType = "model/x-rbxm", content = "BINARY" },
			},
			{ name = "revision", encoding = "text", value = 3 },
			{ name = "note", encoding = "text", value = nil },
		}, transport)

		local boundary = contentType:match("^multipart/form%-data; boundary=(.+)$")
		assert.neq(boundary, nil)
		local expected = table.concat({
			`--{boundary}`,
			'Content-Disposition: form-data; name="request"',
			"Content-Type: application/json",
			"",
			'{"displayName":"Sword"}',
			`--{boundary}`,
			'Content-Disposition: form-data; name="fileContent"; filename="sword.rbxm"',
			"Content-Type: model/x-rbxm",
			"",
			"BINARY",
			`--{boundary}`,
			'Content-Disposition: form-data; name="revision"',
			"",
			"3",
			`--{boundary}--`,
			"",
		}, "\r\n")
		assert.eq(body, expected)
	end)
end)
