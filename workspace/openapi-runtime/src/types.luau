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

export type MultipartField = {
	name: string,
	encoding: MultipartEncoding,
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

export type Operation = {
	method: string,
	path: string,
	pathParams: { [string]: ParamValue }?,
	query: { [string]: QueryValue? }?,
	headers: { [string]: ParamValue? }?,
	body: RequestBody?,
	responseKind: ResponseKind,
}

export type HttpError = {
	method: string,
	url: string,
	status: number,
	body: string,
}

return nil
