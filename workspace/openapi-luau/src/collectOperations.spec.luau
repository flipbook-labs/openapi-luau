local test = require("@std/test")

local collectOperations = require("./collectOperations")

test.suite("collectOperations", function(suite)
	suite:case("keeps operations whose first tag matches, sorted by path then method", function(assert)
		local operations = collectOperations({
			paths = {
				["/b"] = {
					post = { tags = { "Assets" }, summary = "b post" },
					get = { tags = { "Assets" }, summary = "b get" },
				},
				["/a"] = {
					get = { tags = { "Assets", "Avatars" }, summary = "a get" },
				},
				["/c"] = {
					get = { tags = { "Avatars", "Assets" }, summary = "c get" },
					delete = { summary = "untagged" },
				},
			},
		}, "Assets")

		local summaries: { string? } = {}
		for _, operation in operations do
			table.insert(summaries, `{operation.method} {operation.path} {operation.object.summary}`)
		end
		assert.eq(summaries, { "GET /a a get", "GET /b b get", "POST /b b post" })
	end)

	suite:case("merges path-level parameters, resolving refs and letting operations override them", function(assert)
		local operations = collectOperations({
			paths = {
				["/places/{placeId}"] = {
					parameters = {
						{ name = "placeId", ["in"] = "path", description = "path level" },
						{ ["$ref"] = "#/components/parameters/Verbose" },
					},
					get = {
						tags = { "Places" },
						parameters = {
							{ name = "placeId", ["in"] = "path", description = "operation level" },
							{ name = "placeId", ["in"] = "query" },
						},
					},
				},
			},
			components = {
				parameters = {
					Verbose = { name = "verbose", ["in"] = "query" },
				},
			},
		}, "Places")

		local described: { string } = {}
		for _, parameter in operations[1].object.parameters or {} do
			table.insert(described, `{parameter["in"]} {parameter.name} {parameter.description or ""}`)
		end
		assert.eq(described, { "path placeId operation level", "query verbose ", "query placeId " })
	end)
end)
