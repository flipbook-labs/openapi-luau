local test = require("@std/test")

local findJsonMediaType = require("./findJsonMediaType")

test.suite("findJsonMediaType", function(suite)
	suite:case("prefers application/json over other JSON content types", function(assert)
		local contentType = findJsonMediaType({
			["text/json"] = {},
			["application/json"] = {},
		})
		assert.eq(contentType, "application/json")
	end)

	suite:case("accepts vendor types ending in +json", function(assert)
		local contentType = findJsonMediaType({
			["application/merge-patch+json"] = {},
		})
		assert.eq(contentType, "application/merge-patch+json")
	end)

	suite:case("sends application/json for the application/*+json wildcard", function(assert)
		local contentType = findJsonMediaType({
			["application/*+json"] = {},
		})
		assert.eq(contentType, "application/json")
	end)

	suite:case("returns nil when no content type is JSON", function(assert)
		local contentType = findJsonMediaType({
			["multipart/form-data"] = {},
			["application/x-protobuf"] = {},
		})
		assert.eq(contentType, nil)
	end)
end)
