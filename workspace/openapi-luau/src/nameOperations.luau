local collectOperations = require("./collectOperations")
local isIdentifier = require("./isIdentifier")
local toPascalCase = require("./toPascalCase")
local types = require("./types")

type CollectedOperation = collectOperations.CollectedOperation
type Operation = types.Operation

local MAX_SUMMARY_WORDS = 6

local function toCamelCase(text: string): string
	local pascal = toPascalCase(text)
	return pascal:sub(1, 1):lower() .. pascal:sub(2)
end

--[[
	Lists the names an operation could take, from most to least preferred.
	Roblox's operationIds look like `Assets_CreateAsset` or
	`Cloud_CreateTask__Using_Universes`. The part before the first `_` names the
	service. Some operations exist in several forms that differ by path, and the
	part after `__` says which form this is. A few ids also start with a dotted
	namespace, as in `PublicServerBrowserService.GameInstances_GetServerList`,
	which is dropped.

	The first choice is the operationId without its service or form, so those
	become `createAsset` and `createTask`. Next comes the operationId with its
	form kept, as in `createTaskUsingUniverses`. Then a summary made of letters and
	spaces, six words at most, such as "Get Place". Last is the method followed
	by the path's fixed segments, as in `getV1AssetsBundles` for
	`GET /v1/assets/{assetId}/bundles`. A candidate that isn't a valid Luau
	identifier, such as `end` or one starting with a digit, is left out. The
	last candidate is the lowercase method followed by letters and digits, so
	it's always valid and every operation keeps at least one.
]]
local function listCandidates(operation: CollectedOperation): { string }
	local candidates: { string } = {}
	local function add(name: string?)
		if name and isIdentifier(name) and not table.find(candidates, name) then
			table.insert(candidates, name)
		end
	end

	if operation.object.operationId then
		local unqualified = operation.object.operationId:match("([^%.]+)$") or operation.object.operationId
		local base, suffix = unqualified:match("^(.-)__(.+)$")
		base = base or unqualified
		base = base:match("^%w+_(.+)$") or base
		add(toCamelCase(base))
		if suffix then
			add(toCamelCase(base) .. toPascalCase(suffix))
		end
	end

	if operation.object.summary then
		local trimmed = operation.object.summary:gsub("^%s+", ""):gsub("%.?%s*$", "")
		local wordCount = select(2, trimmed:gsub("%S+", ""))
		if trimmed:match("^[%a ]+$") and wordCount <= MAX_SUMMARY_WORDS then
			add(toCamelCase(trimmed))
		end
	end

	local staticSegments = operation.path:gsub("{[^}]*}", "")
	add(operation.method:lower() .. toPascalCase(staticSegments))

	return candidates
end

--[[
	Gives each operation a function name that's unique within its client. Every
	operation starts with its preferred candidate, and only the operations whose
	names collide move on to their next candidate, so an operation keeps its
	short name unless another operation in the same client wants it too. Two
	operations can still match on every candidate, such as `GET /places/{id}`
	and `GET /places/{key}`. The earliest in the list keeps the last candidate,
	and the rest get a number after it. Names that would shadow the generated
	module's locals are never given out.
]]
local function nameOperations(operations: { CollectedOperation }): { Operation }
	local candidates: { { string } } = {}
	local maxLevel = 0
	for index, operation in operations do
		candidates[index] = listCandidates(operation)
		maxLevel = math.max(maxLevel, #candidates[index])
	end

	local names: { [number]: string } = {}
	-- The generated module keeps its types module in this local, so a function
	-- with the same name would shadow it.
	local isTaken: { [string]: boolean } = {
		types = true,
	}

	for level = 1, maxLevel do
		local proposals: { [number]: string } = {}
		local counts: { [string]: number } = {}
		for index in operations do
			if names[index] == nil then
				local list = candidates[index]
				local proposal = list[math.min(level, #list)]
				proposals[index] = proposal
				counts[proposal] = (counts[proposal] or 0) + 1
			end
		end

		for index, proposal in proposals do
			if counts[proposal] == 1 and not isTaken[proposal] then
				names[index] = proposal
				isTaken[proposal] = true
			end
		end
	end

	local named: { Operation } = {}
	for index, operation in operations do
		local name = names[index]
		if name == nil then
			local list = candidates[index]
			local base = list[#list]
			local candidate = base
			local suffix = 2
			while isTaken[candidate] do
				candidate = `{base}{suffix}`
				suffix += 1
			end
			isTaken[candidate] = true
			name = candidate
		end

		table.insert(named, {
			method = operation.method,
			path = operation.path,
			object = operation.object,
			name = name,
		})
	end

	return named
end

return nameOperations
