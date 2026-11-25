--[[
	This repository is a Lute package workspace. The manifest's `package` has no
	name or version, so Lute treats it as the workspace's virtual root, which
	only groups packages and can't be installed itself. Each path dependency is
	a member: a package in its own `workspace/<name>` folder with its own
	`pkg.luau`, which declares that package's dependencies. `lute run install`
	vendors every member's dependencies into this folder's `.lpm/`, so the
	`.lute` scripts can require them too. `dev_dependencies` here holds what no
	member needs, like the agent-skills library that agents read.

	The members release together at one version, the top-level `version` below.
	Each member's manifest requires this file and reads it from there, and
	Changewrite moves it forward at each release. It sits outside `package`
	because Lute only accepts a version there alongside a name.
]]
return {
	version = "0.1.1",
	package = {
		dependencies = {
			["openapi-luau"] = {
				sourceKind = "path",
				source = "./workspace/openapi-luau",
			},
			["openapi-lute-transport"] = {
				sourceKind = "path",
				source = "./workspace/openapi-lute-transport",
			},
			["openapi-runtime"] = {
				sourceKind = "path",
				source = "./workspace/openapi-runtime",
			},
		},
		dev_dependencies = {
			["agent-skills"] = {
				rev = "v0.9.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
			["code-quality"] = {
				rev = "v0.8.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/code-quality",
			},
			["flipbook-batteries"] = {
				rev = "v0.13.1",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/flipbook-batteries",
			},
		},
	},
}
