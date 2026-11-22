local test = require("@std/test")

local buildUrl = require("./buildUrl")

test.suite("buildUrl", function(suite)
	suite:case("fills path parameters and percent-encodes them", function(assert)
		local url = buildUrl("https://apis.example.com", "/stores/{storeId}/entries/{entryId}", {
			storeId = "my store",
			entryId = "a/b",
		})
		assert.eq(url, "https://apis.example.com/stores/my%20store/entries/a%2Fb")
	end)

	suite:case("formats whole-number parameters as plain digits", function(assert)
		local url = buildUrl("https://apis.example.com", "/assets/{assetId}/versions/{version}", {
			assetId = 123456789012345,
			version = 3,
		})
		assert.eq(url, "https://apis.example.com/assets/123456789012345/versions/3")
	end)

	suite:case("keeps literal suffixes such as custom methods after a parameter", function(assert)
		local url = buildUrl("https://apis.example.com", "/assets/{assetId}:archive", {
			assetId = "42",
		})
		assert.eq(url, "https://apis.example.com/assets/42:archive")
	end)

	suite:case("sorts query keys, skips nil values, and repeats array keys", function(assert)
		local url = buildUrl("https://apis.example.com/", "/items", nil, {
			pageSize = 10,
			ids = { 1, 2 },
			filter = "name = 'a&b'",
			isArchived = false,
		})
		assert.eq(
			url,
			"https://apis.example.com/items?filter=name%20%3D%20%27a%26b%27&ids=1&ids=2&isArchived=false&pageSize=10"
		)
	end)

	suite:case("leaves off the query string when every query value is nil", function(assert)
		local url = buildUrl("https://apis.example.com", "/items", nil, {
			pageToken = nil,
		})
		assert.eq(url, "https://apis.example.com/items")
	end)

	suite:case("throws when a path parameter is missing", function(assert)
		assert.throwsWith("missing path parameter 'placeId' for /places/{placeId}", function()
			buildUrl("https://apis.example.com", "/places/{placeId}", {})
		end)
	end)
end)
