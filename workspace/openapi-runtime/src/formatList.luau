local formatParam = require("./formatParam")
local types = require("./types")

type ParamValue = types.ParamValue

--[[
	Joins an array parameter's values with commas, as in `1,2,3`. OpenAPI sends
	arrays this way in headers, and in query and cookie parameters whose
	`explode` is false. Generated clients call this for those parameters, and
	`send` repeats the key for any array left in `query`.

	It's generic because Luau won't pass a `{ number }` where `{ ParamValue }`
	is expected, and generated params type arrays by their items. The items are
	still expected to be strings, numbers, or booleans.
]]
local function formatList<T>(values: { T }?): string?
	if values == nil then
		return nil
	end
	local parts: { string } = {}
	for _, value in values do
		table.insert(parts, formatParam((value :: unknown) :: ParamValue))
	end
	return table.concat(parts, ",")
end

return formatList
