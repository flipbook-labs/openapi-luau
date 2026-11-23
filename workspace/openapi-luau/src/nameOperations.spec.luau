local test = require("@std/test")

local nameOperations = require("./nameOperations")
local types = require("./types")

type OperationObject = types.OperationObject

local function names(operations: { { method: string, path: string, object: OperationObject } }): { string }
	local result: { string } = {}
	for _, operation in nameOperations(operations) do
		table.insert(result, operation.name)
	end
	return result
end

test.suite("nameOperations", function(suite)
	suite:case("drops the service prefix from operationIds", function(assert)
		assert.eq(
			names({
				{ method = "POST", path = "/assets/v1/assets", object = { operationId = "Assets_CreateAsset" } },
				{
					method = "GET",
					path = "/v1/games/{placeId}/servers",
					object = { operationId = "PublicServerBrowserService.GameInstances_GetServerList" },
				},
			}),
			{ "createAsset", "getServerList" }
		)
	end)

	suite:case("adds the __Using suffix only to operationIds that collide", function(assert)
		assert.eq(
			names({
				{ method = "POST", path = "/tasks", object = { operationId = "Cloud_CreateTask__Using_Universes" } },
				{
					method = "POST",
					path = "/versions/tasks",
					object = { operationId = "Cloud_CreateTask__Using_Universes_Places" },
				},
				{ method = "GET", path = "/tasks/{id}", object = { operationId = "Cloud_GetTask__Using_Universes" } },
			}),
			{ "createTaskUsingUniverses", "createTaskUsingUniversesPlaces", "getTask" }
		)
	end)

	suite:case("uses a short summary when there's no operationId", function(assert)
		assert.eq(
			names({
				{ method = "GET", path = "/v1/places/{placeId}", object = { summary = "Get Place Details." } },
			}),
			{ "getPlaceDetails" }
		)
	end)

	suite:case("falls back to the method and path for long or missing summaries", function(assert)
		assert.eq(
			names({
				{
					method = "GET",
					path = "/v1/assets/{assetId}/bundles",
					object = { summary = "Lists the bundles a particular asset belongs to, newest first." },
				},
				{ method = "DELETE", path = "/v2/teamtest/{placeId}", object = {} },
			}),
			{ "getV1AssetsBundles", "deleteV2Teamtest" }
		)
	end)

	suite:case("skips names that would shadow the generated module's locals", function(assert)
		assert.eq(
			names({
				{ method = "GET", path = "/runtime", object = { operationId = "Service_Runtime" } },
				{ method = "GET", path = "/types", object = { summary = "Types" } },
			}),
			{ "getRuntime", "getTypes" }
		)
	end)

	suite:case("numbers names that stay identical after every candidate", function(assert)
		assert.eq(
			names({
				{ method = "GET", path = "/items/{id}", object = { summary = "List Items" } },
				{ method = "GET", path = "/items/{key}", object = { summary = "List Items" } },
			}),
			{ "getItems", "getItems2" }
		)
	end)

	suite:case("skips candidates that aren't valid identifiers", function(assert)
		assert.eq(
			names({
				{ method = "POST", path = "/sessions/end", object = { summary = "End" } },
				{ method = "GET", path = "/codes", object = { operationId = "Auth_2FACodes" } },
			}),
			{ "postSessionsEnd", "getCodes" }
		)
	end)
end)
