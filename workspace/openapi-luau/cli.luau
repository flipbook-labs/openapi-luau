local cliParser = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local luteTransport = require("@workspace/openapi-lute-transport")

local generate = require("./src/generate")
local types = require("./src/types")

local parser = cliParser.parser()
parser:add("spec", "positional", { help = "Path to an OpenAPI 3 document in JSON" })
parser:add("tag", "option", { help = "Generate the operations whose first tag is this" })
parser:add("out", "option", { help = "Folder to write init.luau and types.luau into" })
parser:add("runtime", "option", {
	help = "Require path generated code uses to load openapi-runtime",
})
parser:add("help", "flag", { aliases = { "h" } })

local USAGE = "Usage: openapi-luau <spec> --tag <tag> --out <folder> --runtime <require path>\n"

local function main(args: { string }): number
	parser:parse(args)

	local specPath = parser:get("spec")
	local tag = parser:get("tag")
	local outPath = parser:get("out")
	local runtimeRequire = parser:get("runtime")

	if parser:has("help") then
		print(USAGE)
		print(parser:help())
		return 0
	elseif not (specPath and tag and outPath and runtimeRequire) then
		print(USAGE)
		print(parser:help())
		return 1
	end

	local spec = luteTransport.decodeJson(fs.readFileToString(specPath)) :: types.Spec
	local files = generate(spec, {
		tag = tag,
		runtimeRequire = runtimeRequire,
	})

	fs.createDirectory(outPath, { makeParents = true })
	for name, contents in files do
		local filePath = path.join(outPath, name)
		fs.writeStringToFile(filePath, contents)
		print(`Wrote {filePath}`)
	end
	return 0
end

-- Lute passes the script path as the first argument, ahead of the user's.
local args = { ... }
table.remove(args, 1)
process.exit(main(args))
