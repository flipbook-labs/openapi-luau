local types = require("./types")

type ParamValue = types.ParamValue

local function formatParam(value: ParamValue): string
	if typeof(value) == "number" and value == math.floor(value) and math.abs(value) < 2 ^ 53 then
		return string.format("%d", value)
	end
	return `{value}`
end

return formatParam
