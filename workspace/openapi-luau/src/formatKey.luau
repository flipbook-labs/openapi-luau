local quote = require("./quote")

local RESERVED_WORDS: { [string]: boolean } = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

-- Formats a table key for a type or constructor. A name that isn't a plain
-- identifier, or that is a Luau keyword such as `end`, is quoted and bracketed.
local function formatKey(name: string): string
	if name:match("^[%a_][%w_]*$") and not RESERVED_WORDS[name] then
		return name
	end
	return `[{quote(name)}]`
end

return formatKey
