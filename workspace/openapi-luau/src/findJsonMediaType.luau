local types = require("./types")

type MediaType = types.MediaType

--[[
	Finds the JSON entry in an operation's `content` map, which maps each
	content type the operation accepts or returns to its schema. Any type ending
	in `/json` or `+json` counts, with `application/json` preferred when there
	are several. Returns the content type to send and its entry.

	Documents can list the wildcard `application/*+json`, which names every
	`+json` type at once and isn't a header a server accepts, so that one sends
	`application/json`.
]]
local function findJsonMediaType(content: { [string]: MediaType }): (string?, MediaType?)
	if content["application/json"] then
		return "application/json", content["application/json"]
	end

	local contentTypes: { string } = {}
	for contentType in content do
		local base = contentType:match("^[^;]+") or contentType
		if base:match("[/+]json$") then
			table.insert(contentTypes, contentType)
		end
	end
	table.sort(contentTypes)

	local contentType = contentTypes[1]
	if contentType == nil then
		return nil, nil
	end
	local sentType = if contentType:find("*", 1, true) then "application/json" else contentType
	return sentType, content[contentType]
end

return findJsonMediaType
