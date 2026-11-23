local test = require("@std/test")

local formatList = require("./formatList")

test.suite("formatList", function(suite)
	suite:case("joins values with commas", function(assert)
		local values = {
			1,
			"two",
			true,
			9007199254740991,
		}
		assert.eq(formatList(values), "1,two,true,9007199254740991")
	end)

	suite:case("returns nil for nil", function(assert)
		assert.eq(formatList(nil), nil)
	end)
end)
