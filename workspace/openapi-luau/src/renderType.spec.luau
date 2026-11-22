local test = require("@std/test")

local createTypeContext = require("./createTypeContext")
local renderType = require("./renderType")
local types = require("./types")

type Schema = types.Schema

local function render(schema: Schema, components: { [string]: Schema }?): (string, types.TypeContext)
	local context = createTypeContext({
		components = {
			schemas = components or {},
		},
	}, "types.")
	local text = renderType(schema, context, 0)
	return text, context
end

test.suite("renderType", function(suite)
	suite:case("maps primitive types, treating every integer format as number", function(assert)
		assert.eq(render({ type = "string" }), "string")
		assert.eq(render({ type = "integer", format = "int64" }), "number")
		assert.eq(render({ type = "number" }), "number")
		assert.eq(render({ type = "boolean" }), "boolean")
		assert.eq(render({}), "unknown")
	end)

	suite:case("renders string enums as a union of literals", function(assert)
		assert.eq(render({ type = "string", enum = { "ACTIVE", "ARCHIVED" } }), '"ACTIVE" | "ARCHIVED"')
	end)

	suite:case("renders arrays and maps", function(assert)
		assert.eq(render({ type = "array", items = { type = "string" } }), "{ string }")
		assert.eq(render({ type = "object", additionalProperties = { type = "number" } }), "{\n\t[string]: number,\n}")
		assert.eq(render({ type = "object" }), "{\n\t[string]: unknown,\n}")
	end)

	suite:case("renders objects with sorted fields, optional markers, docs, and quoted keys", function(assert)
		local text = render({
			type = "object",
			required = { "name" },
			properties = {
				name = { type = "string", description = "The display name." },
				["end"] = { type = "boolean" },
				["x-id"] = { type = "string", enum = { "a", "b" } },
			},
		})
		assert.eq(
			text,
			table.concat({
				"{",
				'\t["end"]: boolean?,',
				"\t--- The display name.",
				"\tname: string,",
				'\t["x-id"]: ("a" | "b")?,',
				"}",
			}, "\n")
		)
	end)

	suite:case("marks a nullable optional property optional only once", function(assert)
		local text = render({
			type = "object",
			properties = {
				name = { type = "string", nullable = true },
				kind = { type = "string", nullable = true, enum = { "a", "b" } },
			},
		})
		assert.eq(text, '{\n\tkind: ("a" | "b")?,\n\tname: string?,\n}')
	end)

	suite:case("joins allOf with & and oneOf with |, grouping before a nullable marker", function(assert)
		local components: { [string]: Schema } = {
			["Assets.Asset"] = { type = "object" },
			Creator = { type = "object" },
		}
		assert.eq(
			render({
				allOf = {
					{ ["$ref"] = "#/components/schemas/Assets.Asset" },
					{ ["$ref"] = "#/components/schemas/Creator" },
				},
			}, components),
			"types.AssetsAsset & types.Creator"
		)
		assert.eq(
			render({
				nullable = true,
				oneOf = {
					{ type = "string" },
					{ type = "number" },
				},
			}),
			"(string | number)?"
		)
	end)

	suite:case("records each referenced component", function(assert)
		local _, context = render({ type = "array", items = { ["$ref"] = "#/components/schemas/Creator" } }, {
			Creator = { type = "object" },
			Unused = { type = "object" },
		})
		assert.eq(context.referenced, { Creator = true })
	end)

	suite:case("throws on a ref to a component that doesn't exist", function(assert)
		assert.throwsWith("unknown schema #/components/schemas/Missing", function()
			render({ ["$ref"] = "#/components/schemas/Missing" })
		end)
	end)
end)
