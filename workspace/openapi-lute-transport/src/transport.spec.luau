local test = require("@std/test")

local transport = require("./transport")

test.suite("openapi-lute-transport", function(suite)
	suite:case("decodes JSON into plain tables with nulls removed", function(assert)
		local decoded = transport.decodeJson('{"name":"Sword","owner":null,"tags":["a","b"],"meta":{}}')

		local keys: { unknown } = {}
		for key in decoded :: { [unknown]: unknown } do
			table.insert(keys, key)
		end
		table.sort(keys :: { any }, function(a, b)
			return tostring(a) < tostring(b)
		end)

		assert.eq(keys, { "meta", "name", "tags" })
		assert.eq(decoded, { name = "Sword", tags = { "a", "b" }, meta = {} })
	end)
end)
