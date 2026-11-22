local types = require("./types")

type OperationObject = types.OperationObject
type Spec = types.Spec

export type CollectedOperation = {
	method: string,
	path: string,
	object: OperationObject,
}

local METHODS = table.freeze({ "get", "put", "post", "delete", "options", "head", "patch", "trace" })

-- Collects the operations whose first tag is `tag`, sorted by path and then in
-- the order `METHODS` lists. Tags are the labels an OpenAPI document groups
-- operations under, such as "Assets". An operation can carry several, and its
-- first one is the group it's documented under. Generating one client per tag
-- therefore puts each operation in exactly one client.
local function collectOperations(spec: Spec, tag: string): { CollectedOperation }
	local operations: { CollectedOperation } = {}

	for path, pathItem in spec.paths or {} do
		for _, method in METHODS do
			local object = pathItem[method]
			if object and object.tags and object.tags[1] == tag then
				table.insert(operations, {
					method = method:upper(),
					path = path,
					object = object,
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
