-- Generates typed Luau clients from OpenAPI documents.
local generate = require("@self/src/generate")
local types = require("@self/src/types")

export type GenerateOptions = generate.GenerateOptions
export type GeneratedFiles = types.GeneratedFiles
export type Spec = types.Spec

return {
	generate = generate,
}
