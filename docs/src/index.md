# BuildConstructors.jl

`BuildConstructors.jl` separates model construction from parameter metadata.
Instead of storing fit-specific state inside the model object itself, a constructor
stores descriptors such as `Fixed`, `Running`, `FlexibleParameter`, and
`AdvancedParameter`. The model is then created with `build_model(constructor, pars)`.

This is useful when the final object should stay domain-native, immutable, or owned
by another package, while fitting code still needs names, starting values, bounds,
uncertainties, and fixed/free state.

## Core Workflow

```julia
using BuildConstructors
using Distributions

@with_parameters(Gauss; μ::P, σ::P, pars -> begin
    Normal(μ, σ)
end)

constructor = ConstructorOfGauss(
    AdvancedParameter("μ", 0.0; boundaries = (-5.0, 5.0), uncertainty = 0.1),
    AdvancedParameter("σ", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.1),
)

start = running_values(constructor)
model = build_model(constructor, start)
```

The constructor carries the metadata. The built object is just a `Normal`.

The last comma-separated clause in the `@with_parameters` call must be a unary lambda,
usually **`pars -> begin ... end`**. Rename the binder (`θ`, `p`, ...) if you prefer;
never annotate it (`θ::NamedTuple`). See README: **Less Boilerplate With `@with_parameters`**.

## Optional physics constructors

When you load `JSON`, `Distributions`, `DistributionsHEP`, and `NumericalDistributions`
in the same Julia session, the `PhysicsModelsExt` package extension loads. Use
[`BuildConstructors.physics_models_extension`](@ref) to obtain that module (or
`nothing` if those packages are not loaded). It exports built-in constructors
such as `ConstructorOfBW` and helpers `convert_database_to_prb` and `load_prb_model_from_json`.

```julia
using BuildConstructors
using Distributions, DistributionsHEP, JSON, NumericalDistributions
Phys = physics_models_extension()
Phys === nothing && error("extension not active")
Phys.load_prb_model_from_json("database.json", "bw", "CBpSECH", "Pol2")
```

## Public API

```@docs
BuildConstructors.AbstractParameter
BuildConstructors.Fixed
BuildConstructors.Running
BuildConstructors.FlexibleParameter
BuildConstructors.AdvancedParameter
BuildConstructors.AbstractConstructor
BuildConstructors.build_model
BuildConstructors.running_values
BuildConstructors.running_uncertainties
BuildConstructors.running_lower_boundaries
BuildConstructors.running_upper_boundaries
BuildConstructors.fix!
BuildConstructors.release!
BuildConstructors.update!
BuildConstructors.@with_parameters
BuildConstructors.serialize
BuildConstructors.deserialize
BuildConstructors.physics_models_extension
```
