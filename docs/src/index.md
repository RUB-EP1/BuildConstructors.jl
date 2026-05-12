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

@with_parameters(Gauss; μ::P, σ::P, begin
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
BuildConstructors.convert_database_to_prb
BuildConstructors.load_prb_model_from_json
```
