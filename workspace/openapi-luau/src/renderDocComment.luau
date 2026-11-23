--[[
	Renders text as `---` doc comment lines at the given indentation, ending in
	a newline so callers can put the commented line right after it. Whitespace
	around the whole text and at the end of each line is dropped, so blank lines
	stay clean, while indentation inside the text is kept for Markdown lists.
	Empty text renders as an empty string.
]]
local function renderDocComment(text: string?, indent: string): string
	if text == nil or text:match("^%s*$") then
		return ""
	end

	local lines: { string } = {}
	local normalized = text:gsub("\r\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
	for _, line in normalized:split("\n") do
		local trimmed = line:gsub("%s+$", "")
		table.insert(lines, if trimmed == "" then `{indent}---` else `{indent}--- {trimmed}`)
	end
	return table.concat(lines, "\n") .. "\n"
end

return renderDocComment
