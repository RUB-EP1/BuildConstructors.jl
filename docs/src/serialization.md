# Serialization

Constructor trees can be saved and restored as nested dictionaries — for example
when writing to JSON or a model database. No hand-written per-type methods are
required for ordinary `AbstractConstructor` structs: serialization walks fields
recursively and dispatches on their types.

## Basic usage

```julia
using BuildConstructors

constructor = ConstructorOfGauss(
    AdvancedParameter("μ", 0.0; boundaries = (-5.0, 5.0), uncertainty = 0.1),
    AdvancedParameter("σ", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.1),
)

# After a fit: write values into descriptors, then serialize without extra pars
update!(constructor, fitted)
dict = serialize(constructor)
restored, starting = deserialize(ConstructorOfGauss, dict)
```

Pass `pars` to override specific names (`serialize(constructor; pars=(σ=0.2,))`).
[`Running`](@ref) parameters have no stored default — their names must appear in
`pars` (or be updated elsewhere before serialize).

The second return value of [`deserialize`](@ref) is a `NamedTuple` of starting
values for named parameters (`Running`, `FlexibleParameter`, `AdvancedParameter`).
Pass it to [`build_model`](@ref) as `pars`.

## JSON round-trip

Serialization produces plain `LittleDict`s with no JSON dependency. Add JSON when
you need file I/O:

```julia
using JSON

JSON.print("model.json", dict)
loaded = JSON.parsefile("model.json"; dicttype = OrderedCollections.OrderedDict)
restored, starting = deserialize(ConstructorOfGauss, loaded)
```

Nested constructors and physics types (`ConstructorOfBW`, `ConstructorOfPRBModel`, …)
work the same way once [`PhysicsModelsExt`](@ref BuildConstructors.physics_models_extension)
is loaded — no extra methods to define for those structs.

## How it works

[`serialize`](@ref) adds a `"type"` key (the Julia struct name), then walks
[`fieldnames`](https://docs.julialang.org/en/v1/base/reflection/#Base.fieldnames) of
the constructor:

- **`AbstractParameter` fields** — `Fixed` stores `"value"`; named descriptors store
  `"starting_value"` from `pars` when the name is present, otherwise from the stored
  `.value` on the descriptor (`Running` must be supplied via `pars`).
- **Nested `AbstractConstructor` fields** — serialized recursively.
- **Plain data** (`Tuple`, `Int`, `Float64`, …) — stored as-is.

[`deserialize`](@ref) reads the same structure, resolves nested `"type"` tags through
[`register!`](@ref BuildConstructors.register!), and merges starting values from
nested running parameters.

Manual struct definitions work the same as macro-generated ones — only the field
types matter.

## Custom types

Register custom constructor or parameter names so `"type"` strings can be resolved
(see [`register!`](@ref BuildConstructors.register!)):

```julia
struct MyParameter <: BuildConstructors.AbstractParameter
    scale::Float64
end
BuildConstructors.value(p::MyParameter; pars) = p.scale * first(pars)
BuildConstructors.register!(MyParameter)
```

Fieldless or simple field-only parameter types serialize automatically. Override
[`serialize`](@ref) / [`deserialize`](@ref) when you need special logic (for example
a custom running parameter that reads a non-standard key from `pars`).

## Physics database helper

With the physics extension loaded, `load_prb_model_from_json` reads the bundled
physical–resolution–background database format. That helper is domain-specific;
generic [`serialize`](@ref BuildConstructors.serialize) / [`deserialize`](@ref BuildConstructors.deserialize) cover the constructor
round-trip itself.
