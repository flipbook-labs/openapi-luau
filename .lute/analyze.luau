local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")

local run = FlipbookBatteries.run

run("stylua", { "-c", "workspace", ".lute", "project.luau", "pkg.luau" })

run("luau-lsp", {
	"analyze",
	"--settings=./.vscode/settings.json",
	"workspace",
	".lute",
})
