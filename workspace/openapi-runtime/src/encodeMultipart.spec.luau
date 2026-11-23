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

	suite:case("escapes quotes and backslashes in names and filenames", function(assert)
		local _, body = encodeMultipart({
			{
				name = 'say "hi"',
				encoding = "file",
				value = { filename = [[C:\a "b".txt]], contentType = "text/plain", content = "x" },
			},
		}, transport)

		assert.neq(body:find([[name="say \"hi\""; filename="C:\\a \"b\".txt"]], 1, true), nil)
	end)

	suite:case("throws on a line break in a part header", function(assert)
		assert.throwsWith("multipart field name can't contain a line break", function()
			encodeMultipart({ { name = "a\r\nX-Injected: 1", encoding = "text", value = "x" } }, transport)
		end)
		assert.throwsWith("multipart filename can't contain a line break", function()
			encodeMultipart({
				{
					name = "file",
					encoding = "file",
					value = { filename = "a\nb", contentType = "text/plain", content = "x" },
				},
			}, transport)
		end)
	end)

	suite:case("writes a part's declared content type", function(assert)
		local _, body = encodeMultipart({
			{
				name = "request",
				encoding = "json",
				contentType = "application/vnd.roblox+json",
				value = { displayName = "Sword" },
			},
			{
				name = "csv",
				encoding = "text",
				contentType = "text/csv",
				value = "a,b",
			},
		}, transport)

		assert.neq(body:find('name="request"\r\nContent-Type: application/vnd.roblox+json\r\n', 1, true), nil)
		assert.neq(body:find('name="csv"\r\nContent-Type: text/csv\r\n', 1, true), nil)
	end)
end)
