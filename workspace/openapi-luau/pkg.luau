-- The workspace releases every member at one version, kept in the root
-- manifest.
local root = require("../../pkg")

return {
	package = {
		name = "openapi-luau",
		version = root.version,
		dependencies = {
			batteries = {
				rev = "v1.0.1-nightly.20261115",
				sourceKind = "github",
				source = "https://github.com/luau-lang/lute",
				target = "batteries",
			},
		},
	},
}
