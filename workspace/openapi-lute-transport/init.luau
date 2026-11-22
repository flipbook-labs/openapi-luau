-- A transport for generated clients running on Lute, built on Lute's standard
-- library modules `@std/net` and `@std/json`. It returns a table with the same
-- fields as openapi-runtime's `Transport` type instead of requiring the
-- runtime, so it depends on no other package.
return require("@self/src/transport")
