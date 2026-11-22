-- Generated clients call into this package to send each operation. It builds
-- the request and reads the response, and leaves HTTP and JSON to the
-- transport a client is given.
local send = require("@self/src/send")
local types = require("@self/src/types")

export type Client = types.Client
export type ClientOptions = types.ClientOptions
export type File = types.File
export type HttpError = types.HttpError
export type HttpRequest = types.HttpRequest
export type HttpResponse = types.HttpResponse
export type MultipartEncoding = types.MultipartEncoding
export type Operation = types.Operation
export type ResponseKind = types.ResponseKind
export type Transport = types.Transport

local function createClient(options: ClientOptions): Client
	return {
		baseUrl = options.baseUrl,
		transport = options.transport,
		headers = options.headers or {},
	}
end

return {
	MultipartEncoding = types.MultipartEncoding,
	ResponseKind = types.ResponseKind,
	createClient = createClient,
	send = send,
}
