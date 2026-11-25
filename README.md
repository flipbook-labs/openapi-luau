# OpenApiLuau

OpenApiLuau generates typed Luau clients from OpenAPI 3 documents. Each client is a module with one function per operation and a Luau type for every schema those operations use, so the type checker sees your REST calls the same way it sees the rest of your code.

Generated clients run on Lute. They send requests through a transport you hand them, so the same client can run on another runtime with a different transport.

## Install

Add the generator with Rokit:

```sh
rokit add flipbook-labs/openapi-luau
```

Generated clients depend on `openapi-runtime`, and on Lute they use `openapi-lute-transport`. Add both to your `pkg.luau`:

```luau
dependencies = {
	["openapi-runtime"] = {
		sourceKind = "github",
		source = "https://github.com/flipbook-labs/openapi-luau",
		target = "workspace/openapi-runtime",
		rev = "v0.1.1",
	},
	["openapi-lute-transport"] = {
		sourceKind = "github",
		source = "https://github.com/flipbook-labs/openapi-luau",
		target = "workspace/openapi-lute-transport",
		rev = "v0.1.1",
	},
},
```

## Use

Generate a client from one tag of a document. An operation can carry several tags, and its first tag decides which client it lands in. `--runtime` is the require path the generated code uses to load `openapi-runtime`.

```sh
openapi-luau openapi.json --tag "Luau Execution" --out src/luau-execution --runtime "@lpm/openapi-runtime@v0.1.1"
```

The folder gets an `init.luau` with the operations and a `types.luau` with the schemas. Run StyLua over it afterward to wrap long lines.

Then create a client and call an operation. This one runs a script in a Roblox place through Open Cloud:

```luau
local process = require("@std/process")

local OpenApiLuteTransport = require("@lpm/openapi-lute-transport@v0.1.1")
local OpenApiRuntime = require("@lpm/openapi-runtime@v0.1.1")

local luauExecution = require("./luau-execution")

local client = OpenApiRuntime.createClient({
	baseUrl = "https://apis.roblox.com",
	transport = OpenApiLuteTransport,
	headers = {
		["x-api-key"] = process.env.ROBLOX_API_KEY,
	},
})

local task = luauExecution.createLuauExecutionSessionTaskUsingUniverses(client, {
	universe_id = "1234567890",
	place_id = "9876543210",
	body = {
		script = "return game.PlaceId",
	},
})

print(task.path, task.state)
```

## Names

A function's name comes from the operation's `operationId` with its service prefix dropped, so `Assets_CreateAsset` becomes `createAsset`. Without an `operationId`, a summary of six words or fewer names it, as in `getPlace` for "Get Place". Anything else is named from its method and the fixed parts of its path, such as `getV1AssetsBundles` for `GET /v1/assets/{assetId}/bundles`. When two operations in one client would share a name, only those two move to their next choice, and a number settles any tie that's left.

## Errors

A response outside the 2xx range raises an `HttpError` with the `status`, `body`, `method`, and `url`, so you can handle a specific status:

```luau
local ok, err = pcall(places.getPlace, client, {
	universeId = "1234567890",
	placeId = "9876543210",
})

if not ok and (err :: OpenApiRuntime.HttpError).status == 404 then
	print("That place doesn't exist")
end
```

## Numbers

JSON numbers decode as Luau numbers, including `int64` fields such as IDs. A Luau number holds integers exactly up to 2^53, which covers the IDs APIs hand out today.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.
