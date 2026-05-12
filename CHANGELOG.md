# Changelog

All notable changes to this project are documented in this file.

## 0.5.0

### Changed

- Heavy physics-oriented dependencies (`Distributions`, `DistributionsHEP`, `JSON`, `NumericalDistributions`) are optional and loaded via the `PhysicsModelsExt` package extension when those packages are present.

### Breaking

- Deserialization no longer parses arbitrary Julia expressions from serialized `"type"` strings (previously `eval(Meta.parse(...))`). Only registered type names and simple identifiers resolvable in the extension module (if loaded), `BuildConstructors`, or `Base` are accepted. Parametric forms such as `Fixed{Float64}` in JSON are **not** supported unless you register an explicit name with `register!`. This closes a code-injection risk when loading untrusted JSON.
