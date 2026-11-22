local types = require("./types")

type Spec = types.Spec

-- Follows a local JSON pointer such as `#/components/schemas/Asset`.
local function resolveRef(spec: Spec, ref: string): unknown
	assert(ref:sub(1, 2) == "#/", `only local refs are supported, got {ref}`)

	local current: unknown = spec
	for segment in ref:sub(3):gmatch("[^/]+") do
		local key = segment:gsub("~1", "/"):gsub("~0", "~")
		if typeof(current) ~= "table" then
			error(`could not resolve {ref}`, 0)
		end
		current = (current :: { [string]: unknown })[key]
	end

	if current == nil then
		error(`could not resolve {ref}`, 0)
	end
	return current
end

return resolveRef
