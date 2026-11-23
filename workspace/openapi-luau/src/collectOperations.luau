local resolveRef = require("./resolveRef")
local types = require("./types")

type OperationObject = types.OperationObject
type Parameter = types.Parameter
type PathItem = types.PathItem
type Spec = types.Spec

export type CollectedOperation = {
	method: string,
	path: string,
	object: OperationObject,
}

local METHODS = table.freeze({
	"get",
	"put",
	"post",
	"delete",
	"options",
	"head",
	"patch",
	"trace",
})

local function resolveParameter(spec: Spec, parameter: Parameter): Parameter
	if parameter["$ref"] then
		return resolveRef(spec, parameter["$ref"]) :: Parameter
	end
	return parameter
end

--[[
	Lists the parameters an operation takes. A path item's `parameters` apply to
	every operation under it, and an operation's own parameter replaces one with
	the same name and location. Refs to shared parameters are resolved here, so
	everything after this reads plain parameters.
]]
local function mergeParameters(spec: Spec, pathItem: PathItem, object: OperationObject): { Parameter }
	local merged: { Parameter } = {}
	local indexByKey: { [string]: number } = {}
	local shared = ((pathItem :: { [string]: unknown }).parameters or {}) :: { Parameter }

	for _, list in { shared, object.parameters or {} } do
		for _, entry in list do
			local parameter = resolveParameter(spec, entry)
			local key = `{parameter["in"]}:{parameter.name}`
			local index = indexByKey[key]
			if index then
				merged[index] = parameter
			else
				table.insert(merged, parameter)
				indexByKey[key] = #merged
			end
		end
	end

	return merged
end

--[[
	Collects the operations whose first tag is `tag`, sorted by path and then in
	the order `METHODS` lists. Tags are the labels an OpenAPI document groups
	operations under, such as "Assets". An operation can carry several, and its
	first one is the group it's documented under. Generating one client per tag
	therefore puts each operation in exactly one client.
]]
local function collectOperations(spec: Spec, tag: string): { CollectedOperation }
	local operations: { CollectedOperation } = {}

	for path, pathItem in spec.paths or {} do
		for _, method in METHODS do
			local object = pathItem[method]
			if object and object.tags and object.tags[1] == tag then
				local merged = table.clone(object)
				merged.parameters = mergeParameters(spec, pathItem, object)
				table.insert(operations, {
					method = method:upper(),
					path = path,
					object = merged,
				})
			end
		end
	end

	table.sort(operations, function(a: CollectedOperation, b: CollectedOperation): boolean
		if a.path ~= b.path then
			return a.path < b.path
		end
		return (table.find(METHODS, a.method:lower()) :: number) < (table.find(METHODS, b.method:lower()) :: number)
	end)

	return operations
end

return collectOperations
