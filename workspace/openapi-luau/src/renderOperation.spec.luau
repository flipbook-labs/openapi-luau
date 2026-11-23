local test = require("@std/test")

local createTypeContext = require("./createTypeContext")
local renderOperation = require("./renderOperation")
local types = require("./types")

type OperationObject = types.OperationObject
type Spec = types.Spec

local SPEC: Spec = {
	components = {
		schemas = {
			Asset = { type = "object", properties = { id = { type = "integer" } } },
			Revision = { type = "object", properties = { revision = { type = "integer" } } },
			Binary = { type = "string", format = "binary" },
		},
		requestBodies = {
			CreateAsset = {
				required = true,
				content = {
					["application/json"] = { schema = { ["$ref"] = "#/components/schemas/Asset" } },
				},
			},
		},
		responses = {
			AssetResponse = {
				content = {
					["application/json"] = { schema = { ["$ref"] = "#/components/schemas/Asset" } },
				},
			},
		},
	},
}

-- Renders `object` as an operation named `run` against `SPEC`'s components.
local function render(object: OperationObject): string
	return renderOperation({
		method = "POST",
		path = "/assets",
		object = object,
		name = "run",
	}, createTypeContext(SPEC, "types."))
end

-- Checks that `text` contains `expected` word for word.
local function contains(text: string, expected: string): boolean
	return text:find(expected, 1, true) ~= nil
end

test.suite("renderOperation", function(suite)
	suite:case("reads `required` from a referenced request body", function(assert)
		local text = render({ requestBody = { ["$ref"] = "#/components/requestBodies/CreateAsset" } })

		assert.eq(contains(text, "local function run(client: OpenApiRuntime.Client, args: RunParams)"), true)
		assert.eq(contains(text, "\tbody: types.Asset,"), true)
	end)

	suite:case("reads a referenced response", function(assert)
		local text = render({ responses = { ["200"] = { ["$ref"] = "#/components/responses/AssetResponse" } } })

		assert.eq(contains(text, "): types.Asset\n"), true)
		assert.eq(contains(text, "responseKind = OpenApiRuntime.ResponseKind.Json,"), true)
	end)

	suite:case("groups an optional compound body type", function(assert)
		local text = render({
			requestBody = {
				content = {
					["application/json"] = {
						schema = {
							allOf = {
								{ ["$ref"] = "#/components/schemas/Asset" },
								{ ["$ref"] = "#/components/schemas/Revision" },
							},
						},
					},
				},
			},
		})

		assert.eq(contains(text, "\tbody: (types.Asset & types.Revision)?,"), true)
	end)

	suite:case("sends a referenced binary property as a file with its declared content types", function(assert)
		local text = render({
			requestBody = {
				required = true,
				content = {
					["multipart/form-data"] = {
						schema = {
							type = "object",
							properties = {
								file = { ["$ref"] = "#/components/schemas/Binary" },
								metadata = { type = "string" },
								request = { ["$ref"] = "#/components/schemas/Asset" },
							},
						},
						encoding = {
							metadata = { contentType = "text/csv" },
							request = { contentType = "application/vnd.roblox+json" },
						},
					},
				},
			},
		})

		assert.eq(contains(text, "\t\tfile: OpenApiRuntime.File?,"), true)
		assert.eq(
			contains(
				text,
				'{ name = "metadata", encoding = OpenApiRuntime.MultipartEncoding.Text, contentType = "text/csv", value = args.body["metadata"] },'
			),
			true
		)
		assert.eq(
			contains(
				text,
				'{ name = "request", encoding = OpenApiRuntime.MultipartEncoding.Json, contentType = "application/vnd.roblox+json", value = args.body["request"] },'
			),
			true
		)
	end)

	suite:case("keeps parameters that share a name in different locations apart", function(assert)
		local text = render({
			parameters = {
				{ name = "id", ["in"] = "path", schema = { type = "string" } },
				{ name = "id", ["in"] = "query", schema = { type = "string" } },
				{ name = "body", ["in"] = "query", schema = { type = "string" } },
				{ name = "requestBody", ["in"] = "query", schema = { type = "string" } },
			},
			requestBody = {
				required = true,
				content = { ["text/plain"] = {} },
			},
		})

		assert.eq(contains(text, "\tid: string,\n\tidQuery: string?,"), true)
		assert.eq(contains(text, "\t\t\tid = args.idQuery,"), true)
		assert.eq(contains(text, "\trequestBody2: string,"), true)
		assert.eq(contains(text, "content = args.requestBody2,"), true)
	end)

	suite:case("joins arrays that OpenAPI sends comma-separated", function(assert)
		local text = render({
			parameters = {
				{
					name = "ids",
					["in"] = "query",
					style = "form",
					explode = false,
					schema = { type = "array" },
				},
				{ name = "tags", ["in"] = "query", schema = { type = "array" } },
				{ name = "X-Ids", ["in"] = "header", schema = { type = "array" } },
			},
		})

		assert.eq(contains(text, "\t\t\tids = OpenApiRuntime.formatList(args.ids),"), true)
		assert.eq(contains(text, "\t\t\ttags = args.tags,"), true)
		assert.eq(contains(text, '\t\t\t["X-Ids"] = OpenApiRuntime.formatList(args["X-Ids"]),'), true)
	end)

	suite:case("sends cookie parameters as cookies", function(assert)
		local text = render({
			parameters = {
				{
					name = "session",
					["in"] = "cookie",
					required = true,
					schema = { type = "string" },
				},
			},
		})

		assert.eq(contains(text, "\tsession: string,"), true)
		assert.eq(contains(text, "\t\tcookies = {\n\t\t\tsession = args.session,\n\t\t},"), true)
	end)

	suite:case("throws on parameter shapes it can't send", function(assert)
		assert.throwsWith("query parameter 'filter' is an object, which isn't supported", function()
			render({
				parameters = {
					{ name = "filter", ["in"] = "query", schema = { type = "object" } },
				},
			})
		end)
		assert.throwsWith("query parameter 'ids' uses style 'pipeDelimited', which isn't supported", function()
			render({
				parameters = {
					{
						name = "ids",
						["in"] = "query",
						style = "pipeDelimited",
						schema = { type = "array" },
					},
				},
			})
		end)
	end)
end)
