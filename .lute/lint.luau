local CodeQuality = require("@lpm/code-quality@v0.8.0")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")

local run = FlipbookBatteries.run

local LINTED_PATHS = {
	"workspace",
	".lute",
	"project.luau",
	"pkg.luau",
}

run("stylua", { "--check", table.unpack(LINTED_PATHS) })

CodeQuality.lint(LINTED_PATHS)
