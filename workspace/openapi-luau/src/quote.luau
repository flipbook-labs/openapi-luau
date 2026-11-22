local ESCAPES: { [string]: string } = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

-- Writes `text` as a double-quoted Luau string literal.
local function quote(text: string): string
	local escaped = text:gsub('[\\"\n\r\t]', ESCAPES):gsub("[%c\128-\255]", function(character)
		return string.format("\\x%02X", character:byte())
	end)
	return `"{escaped}"`
end

return quote
