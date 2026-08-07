# Changelog

All notable changes to this project are documented in this file.

## 0.7.0

### Added

- `validate_parameters`: walk a constructor tree at construction time, warn on shared parameter names with equal descriptors, and throw when the same name appears with incompatible descriptors. Macro-generated constructors call this automatically; manual `AbstractConstructor` types can opt in after `new`.
- Structural `==` for `AbstractParameter` subtypes.

### Changed

- `PhysicsModelsExt` no longer depends on `DistributionsHEP`. Built-in `CrystalBall` and `Chebyshev` distributions are provided directly by the extension, which removes version conflicts with packages such as `HighEnergyTools`. Fixes #45.
- `@with_parameters`: generated struct fields and constructor positional arguments now follow macro header declaration order instead of reordering by field kind (parametric, descriptor, constant).
- `@with_parameters`: struct type parameters (`P*`, `T*`) now follow the same declaration order as fields and constructor arguments, instead of grouping all `P*` before all `T*`.
- Duplicate parameter names are validated when a constructor is created, not when metadata collectors such as `parameter_values` are called.

### Breaking

- `PhysicsModelsExt` no longer loads `DistributionsHEP`. Activate it with `Distributions`, `JSON`, `NumericalDistributions`, `Polynomials`, and `SpecialFunctions` instead. `CrystalBall` and `Chebyshev` are exported from the extension itself.
- `@with_parameters`: constructor positional argument order now matches the macro field list. Code that relied on the previous reordering (for example `ConstructorOfPRBModel(model_p, model_r, model_b, fs, ...)`) must pass arguments in declaration order (`ConstructorOfPRBModel(fs, model_p, model_r, model_b, ...)`). Fixes #39.
- Macro-generated constructors now throw at construction when nested or sibling parameters reuse a name with incompatible descriptors. Previously, conflicting duplicates could survive until a metadata collector was called.
- `parameter_values`, `parameter_names`, and related projection helpers no longer reject conflicting duplicate names. They deduplicate by name without validation overhead; call `validate_parameters` during construction to enforce consistency. Fixes #47.

## 0.6.0

### Added

- Parameter metadata collectors: `parameter_values`, `parameter_uncertainties`, `parameter_lower_boundaries`, and `parameter_upper_boundaries`.
- Parameter state name collectors: `parameter_names`, `running_names`, and `fixed_names`.
- Filtered state metadata collectors: `running_values`, `running_uncertainties`, `running_lower_boundaries`, `running_upper_boundaries`, `fixed_values`, `fixed_uncertainties`, `fixed_lower_boundaries`, and `fixed_upper_boundaries`.

## 0.5.0

### Changed

- Heavy physics-oriented dependencies (`Distributions`, `DistributionsHEP`, `JSON`, `NumericalDistributions`) are optional and loaded via the `PhysicsModelsExt` package extension when those packages are present.
- `@with_parameters`: every field listed in the macro header is bound as a local inside the generated `build_model` (`field::P` via `value`, parametric and typed slots via `c.field`). Documentation, README, extension examples, and tutorials use bare names consistently.
- `@with_parameters`: macro implementation trimmed (removed unused bookkeeping, combined prelude emission into one pass over fields).
- Tests: `test/test-macro.jl` is loaded from `test/runtests.jl` so macro coverage runs under `Pkg.test()`.

### Breaking

- Deserialization no longer parses arbitrary Julia expressions from serialized `"type"` strings (previously `eval(Meta.parse(...))`). Only registered type names and simple identifiers resolvable in the extension module (if loaded), `BuildConstructors`, or `Base` are accepted. Parametric forms such as `Fixed{Float64}` in JSON are **not** supported unless you register an explicit name with `register!`. This closes a code-injection risk when loading untrusted JSON.
- `@with_parameters`: do not use `_.field` in the body; use bare names that match the field list for constructor fields. Other `build_model` call patterns follow normal Julia scoping (undeclared names surface as runtime `UndefVarError` where appropriate).
