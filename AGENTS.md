# OpenApiLuau agent guide

OpenApiLuau generates typed Luau clients from OpenAPI 3 documents. It is written in Luau, runs on Lute, and compiles to a native binary. This file is the entry point for any agent working in the repo. It routes you to the shared skills library and the repo's own setup.

## Mandatory first steps

Complete every step below before you write any code, tests, changelog entries, or PR prose. This is a gate, and it does not depend on how you classify your task.

1. Install the toolchain and dependencies:

   ```sh
   rokit install && lute run install
   ```

   `rokit install` puts `lute`, `luau-lsp`, `stylua`, and `changewrite` on PATH. `lute run install` copies the dependencies into `.lpm/<key>@<rev>` folders, and code requires them through the `lpm` alias in `.config.luau`. The shared skills library is a dev dependency, so it lands in `.lpm/` for you to read but isn't bundled into the binary.

2. Find the skills folder: it's `.lpm/agent-skills@<rev>`, with the `rev` pinned in [`pkg.luau`](pkg.luau). Use that path wherever `<skills>` appears below.

3. Read the routing index at `<skills>/AGENTS.md` in full. Its **Project Skills** section lists every skill with a trigger-rich one-liner, so you know what exists before you start. This read is unconditional.

Deep reads of individual `<skills>/src/<scope>/<name>/SKILL.md` files stay on demand: when a task matches a trigger from the index, read that skill before doing the work it covers.

Before you call a task done, follow the `org/review-pass` skill: it maps the diff to the skills that govern each file, has you re-open them, runs the writing-style and code-comments critic passes over what you generated, and catches skill drift to feed back.

## Forward this file to subagents

The Task tool spawns subagents in a fresh context that does not include this guide. Whenever you delegate to a subagent, include in its prompt:

1. The mandatory first steps above (the bootstrap command and the index read).
2. The concrete resolved path(s) to the specific `SKILL.md` files relevant to its task.

## Keeping skills current

When your work here contradicts a skill, fix it in the agent-skills repo with a `.changes/` entry in the same effort. The fix reaches this repo on its next `rev` bump.

## Repo specifics

- `lute run --list` shows the scripts: `install`, `lint` (StyLua and [Code Quality](https://github.com/flipbook-labs/code-quality)'s lint rules), `analyze` (luau-lsp type checks), and `build` (compile the `openapi-luau` binary into `build/`). Run the tests with `lute test`. Tests are `*.spec.luau` files beside the code they cover.
- The repository is a Lute package workspace. The root [`pkg.luau`](pkg.luau) has no name or version, and each folder under `workspace/` is a member with its own `pkg.luau`:
  - [`openapi-luau`](workspace/openapi-luau) is the generator. Its CLI entry point is [`cli.luau`](workspace/openapi-luau/cli.luau), and [`src/generate.luau`](workspace/openapi-luau/src/generate.luau) turns a document and a tag into `init.luau` and `types.luau`.
  - [`openapi-runtime`](workspace/openapi-runtime) is what generated clients call into. It builds requests and leaves HTTP and JSON to a transport, so it uses no runtime-specific APIs.
  - [`openapi-lute-transport`](workspace/openapi-lute-transport) is the transport for Lute, built on `@std/net` and `@std/json`.
- Other repositories vendor the runtime and transport, so code inside them uses relative requires rather than repo aliases like `@workspace`.
- Releases go through Changewrite: unreleased entries live in [`.changes/`](.changes) and are assembled into `CHANGELOG.md` at release time.
