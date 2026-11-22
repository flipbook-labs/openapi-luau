return {
	categories = { "Features", "Fixes", "Changes", "Dependencies" },
	version = {
		current = "0.0.0",
		mirror = {
			{ file = "workspace/openapi-luau/pkg.luau" },
			{ file = "workspace/openapi-runtime/pkg.luau" },
			{ file = "workspace/openapi-lute-transport/pkg.luau" },
			{ file = "README.md", pattern = 'target = "workspace/openapi%-runtime",%s+rev = "v([%d%.]+)"' },
			{ file = "README.md", pattern = 'target = "workspace/openapi%-lute%-transport",%s+rev = "v([%d%.]+)"' },
			{ file = "README.md", pattern = '%-%-runtime "@lpm/openapi%-runtime@v([%d%.]+)"' },
			{ file = "README.md", pattern = 'require%("@lpm/openapi%-runtime@v([%d%.]+)"%)' },
			{ file = "README.md", pattern = 'require%("@lpm/openapi%-lute%-transport@v([%d%.]+)"%)' },
		},
	},
	kind = {
		Generator = { text = "Generator", color = "#1f883d" },
		Runtime = { text = "Runtime", color = "#2f81f7" },
		Transport = { text = "Transport", color = "#7c5cff" },
		Tooling = { text = "Tooling", color = "#6e7781" },
	},
}
