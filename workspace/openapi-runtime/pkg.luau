-- The workspace releases every member at one version, kept in the root
-- manifest.
local root = require("../../pkg")

return {
	package = {
		name = "openapi-runtime",
		version = root.version,
		dependencies = {},
	},
}
