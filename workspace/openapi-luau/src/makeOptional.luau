-- Adds `?` to a rendered type. A type that's already optional, such as a
-- nullable schema, is returned as is, and a union or intersection is wrapped in
-- parentheses first so the `?` covers all of it.
local function makeOptional(text: string, isCompound: boolean): string
	if text:sub(-1) == "?" then
		return text
	end
	return if isCompound then `({text})?` else `{text}?`
end

return makeOptional
