-- Percent-encodes every byte outside RFC 3986's unreserved set, so the result
-- is safe in both a path segment and a query component.
local function percentEncode(text: string): string
	return (text:gsub("[^%w%-%._~]", function(character)
		return string.format("%%%02X", string.byte(character))
	end))
end

return percentEncode
