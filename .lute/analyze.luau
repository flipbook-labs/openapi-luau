local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")

local run = FlipbookBatteries.run

run("luau-lsp", {
	"analyze",
	"--settings=./.vscode/settings.json",
	"workspace",
	".lute",
})
