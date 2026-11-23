-- The workspace releases every member at one version, kept in the root
-- manifest.
local root = require("../../pkg")

return {
	package = {
		name = "openapi-lute-transport",
		version = root.version,
		dependencies = {},
	},
}
