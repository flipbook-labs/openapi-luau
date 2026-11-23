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

-- Whether `name` can be written bare in Luau source, as a local, a function, or
-- a table key: letters, digits, and underscores, not starting with a digit,
-- and not a keyword such as `end`.
local function isIdentifier(name: string): boolean
	return name:match("^[%a_][%w_]*$") ~= nil and not RESERVED_WORDS[name]
end

return isIdentifier
