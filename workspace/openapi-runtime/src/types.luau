export type HttpRequest = {
	url: string,
	method: string,
	headers: { [string]: string },
	body: string?,
}

export type HttpResponse = {
	status: number,
	headers: { [string]: string },
	body: string,
}

-- Everything a client needs from the platform it runs on. Generated clients
-- stay free of runtime-specific APIs, so running one somewhere other than Lute
-- takes only a transport written for that runtime.
export type Transport = {
	request: (request: HttpRequest) -> HttpResponse,
	encodeJson: (value: unknown) -> string,
	decodeJson: (text: string) -> unknown,
}

export type Client = {
	baseUrl: string,
	transport: Transport,
	headers: { [string]: string },
}

export type ClientOptions = {
	baseUrl: string,
	transport: Transport,
	headers: { [string]: string }?,
}

export type ParamValue = string | number | boolean

export type QueryValue = ParamValue | { ParamValue }

export type File = {
	filename: string,
	contentType: string,
	content: string,
}

export type MultipartEncoding = "json" | "file" | "text"

-- How `send` writes a multipart field: `Json` encodes a value as JSON, `File`
-- sends a `File`'s content with its filename, and `Text` sends a string,
-- number, or boolean as text.
local MultipartEncoding = table.freeze({
	Json = "json" :: "json",
	File = "file" :: "file",
	Text = "text" :: "text",
})

-- `contentType` is the part's declared media type. A `File` part uses the
-- file's own `contentType` instead.
export type MultipartField = {
	name: string,
	encoding: MultipartEncoding,
	contentType: string?,
	value: unknown,
}

export type RequestBody =
	{
		kind: "json",
		contentType: string,
		value: unknown,
	}
	| {
		kind: "multipart",
		fields: { MultipartField },
	}
	| {
		kind: "raw",
		contentType: string,
		content: string,
	}

export type ResponseKind = "json" | "text" | "none"

-- How `send` reads a response body: `Json` decodes it, `Text` returns it as a
-- string, and `None` ignores it.
local ResponseKind = table.freeze({
	Json = "json" :: "json",
	Text = "text" :: "text",
	None = "none" :: "none",
})

export type Operation = {
	method: string,
	path: string,
	pathParams: { [string]: ParamValue }?,
	query: { [string]: QueryValue? }?,
	headers: { [string]: ParamValue? }?,
	cookies: { [string]: ParamValue? }?,
	body: RequestBody?,
	responseKind: ResponseKind,
}

export type HttpError = {
	method: string,
	url: string,
	status: number,
	body: string,
}

return {
	MultipartEncoding = MultipartEncoding,
	ResponseKind = ResponseKind,
}
