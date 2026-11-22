local formatParam = require("./formatParam")
local percentEncode = require("./percentEncode")
local types = require("./types")

type ParamValue = types.ParamValue
type QueryValue = types.QueryValue

-- Fills each `{name}` in the path template and appends the query string. Query
-- keys are sorted so the same call always builds the same URL. An array value
-- always repeats its key once per item, as in `ids=1&ids=2`. That's the
-- OpenAPI default for query arrays, and the only array style supported.
local function buildUrl(
	baseUrl: string,
	pathTemplate: string,
	pathParams: { [string]: ParamValue }?,
	query: { [string]: QueryValue? }?
): string
	local path = pathTemplate:gsub("{([^}]+)}", function(name: string)
		local value = if pathParams then pathParams[name] else nil
		if value == nil then
			error(`missing path parameter '{name}' for {pathTemplate}`, 0)
		end
		return percentEncode(formatParam(value))
	end)

	local pairsList: { string } = {}
	if query then
		local keys: { string } = {}
		for key in query do
			table.insert(keys, key)
		end
		table.sort(keys)

		for _, key in keys do
			local value = query[key]
			if typeof(value) == "table" then
				for _, item in value do
					table.insert(pairsList, `{percentEncode(key)}={percentEncode(formatParam(item))}`)
				end
			elseif value ~= nil then
				table.insert(pairsList, `{percentEncode(key)}={percentEncode(formatParam(value))}`)
			end
		end
	end

	local base = baseUrl:gsub("/+$", "")
	local url = base .. path
	if #pairsList > 0 then
		url ..= "?" .. table.concat(pairsList, "&")
	end
	return url
end

return buildUrl
