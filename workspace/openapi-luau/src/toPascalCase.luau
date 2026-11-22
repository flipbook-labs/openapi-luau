-- Joins the alphanumeric words in `text` into PascalCase, keeping the case of
-- letters after each word's first, so `createLuauExecutionSessionTask` and
-- `AssetsUploadApi.Asset` keep their inner capitals.
local function toPascalCase(text: string): string
	local words: { string } = {}
	for word in text:gmatch("[%w]+") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(words)
end

return toPascalCase
