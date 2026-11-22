--[[
	The parts of an OpenAPI 3.0 document the generator reads. The CLI casts the
	decoded JSON to `Spec` without validating it, so most fields are optional and
	checked where they're used. A parameter's `name` and `in` are required by the
	OpenAPI spec and used as is.
]]
export type Schema = {
	["$ref"]: string?,
	type: string?,
	format: string?,
	description: string?,
	properties: { [string]: Schema }?,
	required: { string }?,
	items: Schema?,
	additionalProperties: (boolean | Schema)?,
	allOf: { Schema }?,
	oneOf: { Schema }?,
	anyOf: { Schema }?,
	enum: { unknown }?,
	nullable: boolean?,
}

export type Parameter = {
	name: string,
	["in"]: string,
	required: boolean?,
	description: string?,
	schema: Schema?,
}

export type Encoding = {
	contentType: string?,
}

export type MediaType = {
	schema: Schema?,
	encoding: { [string]: Encoding }?,
}

export type RequestBody = {
	["$ref"]: string?,
	required: boolean?,
	description: string?,
	content: { [string]: MediaType }?,
}

export type Response = {
	description: string?,
	content: { [string]: MediaType }?,
}

export type OperationObject = {
	tags: { string }?,
	summary: string?,
	description: string?,
	operationId: string?,
	deprecated: boolean?,
	parameters: { Parameter }?,
	requestBody: RequestBody?,
	responses: { [string]: Response }?,
	externalDocs: { url: string? }?,
}

export type Spec = {
	openapi: string?,
	info: { title: string?, version: string? }?,
	paths: { [string]: { [string]: OperationObject } }?,
	components: {
		schemas: { [string]: Schema }?,
		requestBodies: { [string]: RequestBody }?,
	}?,
}

-- One operation selected for generation, with the function name it gets.
export type Operation = {
	method: string,
	path: string,
	object: OperationObject,
	name: string,
}

--[[
	Tracks component schemas while rendering. Components are the reusable
	schemas under `components.schemas` that other schemas point to with `$ref`.
	`typeNames` maps each component to its Luau type name, and `referenced`
	collects the components a rendered type uses so the types module includes
	exactly those. `typePrefix` goes in front of each type name, so code in
	`init.luau` writes `types.Asset` while `types.luau` itself writes `Asset`.
]]
export type TypeContext = {
	spec: Spec,
	typeNames: { [string]: string },
	referenced: { [string]: true },
	typePrefix: string,
}

export type GeneratedFiles = { [string]: string }

return nil
