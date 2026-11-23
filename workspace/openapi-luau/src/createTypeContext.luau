local toPascalCase = require("./toPascalCase")
local types = require("./types")

type Spec = types.Spec
type TypeContext = types.TypeContext

--[[
	Gives every component schema a Luau type name. Names come from the whole
	component name, so `AssetsUploadApi.Asset` becomes `AssetsUploadApiAsset`,
	and later components in sorted order get a numeric suffix on a clash.

	The client module re-exports these types beside types of its own, such as
	`Client` and each operation's params type. `reservedNames` lists those, so a
	component that would take one gets a suffix instead.
]]
local function createTypeContext(spec: Spec, typePrefix: string, reservedNames: { string }?): TypeContext
	local componentNames: { string } = {}
	local schemas = if spec.components then spec.components.schemas else nil
	for name in schemas or {} do
		table.insert(componentNames, name)
	end
	table.sort(componentNames)

	local typeNames: { [string]: string } = {}
	local isTaken: { [string]: boolean } = {}
	for _, name in reservedNames or {} do
		isTaken[name] = true
	end
	for _, name in componentNames do
		local base = toPascalCase(name)
		if base == "" or base:match("^%d") then
			base = "Schema" .. base
		end

		local typeName = base
		local suffix = 2
		while isTaken[typeName] do
			typeName = `{base}{suffix}`
			suffix += 1
		end

		isTaken[typeName] = true
		typeNames[name] = typeName
	end

	return {
		spec = spec,
		typeNames = typeNames,
		referenced = {},
		typePrefix = typePrefix,
	}
end

return createTypeContext
