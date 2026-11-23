local isIdentifier = require("./isIdentifier")
local quote = require("./quote")

-- Formats a table key for a type or constructor. A name that isn't a plain
-- identifier, or that is a Luau keyword such as `end`, is quoted and bracketed.
local function formatKey(name: string): string
	if isIdentifier(name) then
		return name
	end
	return `[{quote(name)}]`
end

return formatKey
