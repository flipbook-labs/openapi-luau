--[[
	The parts of an OpenAPI 3.0 document the generator reads. The CLI casts the
	decoded JSON to `Spec` without validating it, so most fields are optional and
	checked where they're used. A parameter's `name` and `in` are required by the
	OpenAPI spec and used as is, once any `$ref` is resolved.
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
	["$ref"]: string?,
	name: string,
	["in"]: string,
	required: boolean?,
	style: string?,
	explode: boolean?,
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
	["$ref"]: string?,
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

-- A path's operations, keyed by method, plus `parameters` shared by all of
-- them. Luau can't type a table whose `parameters` key differs from the rest,
-- so `collectOperations` reads `parameters` through a cast.
export type PathItem = { [string]: OperationObject }

export type Spec = {
	openapi: string?,
	info: { title: string?, version: string? }?,
	paths: { [string]: PathItem }?,
	components: {
		schemas: { [string]: Schema }?,
		requestBodies: { [string]: RequestBody }?,
		parameters: { [string]: Parameter }?,
		responses: { [string]: Response }?,
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
