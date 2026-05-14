# Changelog

All notable changes to this project are documented in this file.

## 0.5.0

### Changed

- Heavy physics-oriented dependencies (`Distributions`, `DistributionsHEP`, `JSON`, `NumericalDistributions`) are optional and loaded via the `PhysicsModelsExt` package extension when those packages are present.
- `@with_parameters`: every field listed in the macro header is bound as a local inside the generated `build_model` (`field::P` via `value`, parametric and typed slots via `c.field`). Documentation, README, extension examples, and tutorials use bare names consistently.
- `@with_parameters`: macro implementation trimmed (removed unused bookkeeping, combined prelude emission into one pass over fields).
- Tests: `test/test-macro.jl` is loaded from `test/runtests.jl` so macro coverage runs under `Pkg.test()`.

### Breaking

- Deserialization no longer parses arbitrary Julia expressions from serialized `"type"` strings (previously `eval(Meta.parse(...))`). Only registered type names and simple identifiers resolvable in the extension module (if loaded), `BuildConstructors`, or `Base` are accepted. Parametric forms such as `Fixed{Float64}` in JSON are **not** supported unless you register an explicit name with `register!`. This closes a code-injection risk when loading untrusted JSON.
- `@with_parameters`: do not use `_.field` in the body; use bare names that match the field list for constructor fields. Other `build_model` call patterns follow normal Julia scoping (undeclared names surface as runtime `UndefVarError` where appropriate).
