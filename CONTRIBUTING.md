# Contributing to OpenApiLuau

## Setup

OpenApiLuau uses [Rokit](https://github.com/rojo-rbx/rokit) for toolchain management.

```sh
rokit install
lute run install   # vendor dependencies into .lpm/
lute run analyze   # run the StyLua and luau-lsp checks
lute run build     # compile the openapi-luau binary into build/
lute test          # run the *.spec.luau test suite
```

`lute run install` copies the dependencies into `.lpm/<key>@<rev>` folders, and code requires them through the `lpm` alias in `.config.luau`, which `lute compile` bundles into the binary. It also fetches the shared [agent-skills](https://github.com/flipbook-labs/agent-skills) library that [`AGENTS.md`](AGENTS.md) routes agents to. That library is a dev dependency, so it lands in `.lpm/` but isn't bundled into the binary.

## Trying the generator

Run the CLI from source against any OpenAPI 3 document in JSON. Roblox publishes Open Cloud as one, [`openapi.json`](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/cloud/openapi.json), which makes a good large test case:

```sh
lute run workspace/openapi-luau/cli.luau openapi.json --tag "Luau Execution" --out out/luau-execution --runtime "@openapi-runtime"
```

## Changelog entries

Each pull request adds one entry under `.changes/`, as described in [`.changes/README.md`](.changes/README.md). Merging the publish PR that Changewrite keeps open cuts the next version.
