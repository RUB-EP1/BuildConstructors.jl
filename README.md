# BuildConstructors.jl

Attach metadata to model parameters — names, starting values, bounds, fixed/free
state — without polluting the model object itself. Walk a nested constructor tree
and discover every parameter in one place.

The final object stays domain-native: a `Normal`, a PDF, an amplitude, a callable.
The constructor holds the fit bookkeeping.

## Installation

```julia
] add https://github.com/RUB-EP1/BuildConstructors.jl
```

## The problem

Fitting workflows need more than numbers. Optimizers want bounds and starting
points; analysis code wants names and uncertainties; nested models need all of
that collected recursively from sub-components.

Attaching that metadata directly to user objects is awkward: objects are often
immutable, come from other packages, or have no natural place for a default
value. **Wrap construction instead** — store descriptors in a constructor, pass
trial values at build time, call `build_model(constructor, pars)`.

## Three-step workflow

### 1. Define model shapes once (`src/`)

Use `@with_parameters` to declare how descriptors become a real object. Each macro
block generates a `ConstructorOf…` type and a matching `build_model` method.

```julia
using BuildConstructors
using Distributions

@with_parameters(Gauss; μ::P, σ::P, begin
    Normal(μ, σ)
end)

@with_parameters(Mixture; left, right, f_left::P, begin
    MixtureModel(
        [build_model(left, pars), build_model(right, pars)],
        [f_left, 1 - f_left],
    )
end)
```

Field roles in the macro header:

| Form | Meaning |
| --- | --- |
| `field::P` | Fit parameter. Resolved from `pars` in the body as `field`. |
| `field::SomeType` | Fixed configuration on the constructor (e.g. a fit window). |
| `field` | Nested constructor or other slot; use bare `field` in the body. |

Positional constructor arguments follow the same order as the field list.

`@with_parameters` is optional convenience: it expands to a `ConstructorOf…` struct
and a `build_model` method you could write explicitly — just with more boilerplate.
Use `@macroexpand` to inspect the generated code:

```julia
@macroexpand @with_parameters(Gauss; μ::P, σ::P, begin
    Normal(μ, σ)
end)
```

### 2. Build a constructor — the object your optimizer sees

Instantiate the generated type with parameter descriptors. This tree is what you
inspect, serialize, fix/release, and hand to your fitting backend.

```julia
constructor = ConstructorOfMixture(
    ConstructorOfGauss(
        AdvancedParameter("μ_left", -0.5; boundaries=(-5.0, 5.0), uncertainty=0.1),
        AdvancedParameter("σ_left", 1.0; boundaries=(0.05, 5.0), uncertainty=0.05),
    ),
    ConstructorOfGauss(
        AdvancedParameter("μ_right", 0.7; boundaries=(-5.0, 5.0), uncertainty=0.1),
        AdvancedParameter("σ_right", 1.0; boundaries=(0.05, 5.0), uncertainty=0.05),
    ),
    AdvancedParameter("f_left", 0.5; boundaries=(0.0, 1.0), uncertainty=0.02),
)

start = running_values(constructor)
lower = running_lower_boundaries(constructor)
upper = running_upper_boundaries(constructor)
uncertainties = running_uncertainties(constructor)
```

Nested constructors are discovered automatically. The `running_*` collectors walk
the whole tree and return only the parameters that are currently free. After
`fix!(constructor, (:μ_left,))`, the fit vector shrinks automatically:

```julia
fix!(constructor, (:μ_left,))
running_values(constructor)              # no longer includes μ_left
running_lower_boundaries(constructor)
running_upper_boundaries(constructor)
running_uncertainties(constructor)
```

Use `parameter_values` and the other `parameter_*` collectors when you need
metadata for every named descriptor, including fixed ones.

### 3. Optimize: `build_model` produces whatever you need

In the objective, turn trial parameters into the real model, then evaluate your
metric (PDF, NLL, amplitude, …):

```julia
using Optim, ComponentArrays

function nll(c, data, pars)
    model = build_model(c, pars)
    return -sum(logpdf.(Ref(model), data))
end

start_ca = ComponentArray(start)
lower_ca = ComponentArray(lower)
upper_ca = ComponentArray(upper)

result = optimize(pars -> nll(constructor, data, pars), lower_ca, upper_ca, start_ca, Fminbox(LBFGS()))
fitted = Optim.minimizer(result)

update!(constructor, fitted)   # write fitted values back into the descriptor tree
```

`pars` is deliberately unconstrained — `NamedTuple`, `ComponentArray`, or any
object your descriptors can read. Built-in descriptors use `getproperty`, so
`pars.μ_left` works out of the box.

The same pattern applies to any return type: wrap `build_model` in your own
`extended_negative_log_likelihood(constructor, pars, data)` or
`amplitude(constructor, pars, x)` helpers.

## Parameter descriptors

| Descriptor | Role |
| --- | --- |
| `Fixed(value)` | Constant; not collected as a named parameter. |
| `Running(name)` | Free parameter read from `pars` by name. |
| `FlexibleParameter(name, value)` | Stored value; can be fixed or released. |
| `AdvancedParameter(name, value; boundaries, uncertainty, fixed)` | Stored value with bounds, uncertainty, and fixed/free state. |

Define your own by subtyping `AbstractParameter` and implementing `value(p; pars)`.

## Metadata API

These methods recurse into nested `AbstractConstructor` fields:

```julia
parameter_metadata(constructor)
parameter_values(constructor)
parameter_names(constructor)
parameter_uncertainties(constructor)
parameter_lower_boundaries(constructor)
parameter_upper_boundaries(constructor)

running_names(constructor)
running_values(constructor)
running_uncertainties(constructor)
running_lower_boundaries(constructor)
running_upper_boundaries(constructor)

fixed_names(constructor)
fixed_values(constructor)
fixed_uncertainties(constructor)
fixed_lower_boundaries(constructor)
fixed_upper_boundaries(constructor)

fix!(constructor, (:σ,))
release!(constructor, (:σ,))
update!(constructor, (σ=0.25,))
```

When names repeat, metadata keeps every entry; projected collectors such as
`parameter_values` deduplicate by name (last wins). Macro-generated constructors
validate the tree at construction time; manual types can call `validate_parameters`
after `new`.

## Serialization (optional)

Save and restore constructor descriptions through JSON or database workflows:

```julia
BuildConstructors.register!(ConstructorOfMyModel)
serialize(constructor; pars)
deserialize(Type{ConstructorOfMyModel}, dict)
```

Serialization is optional; the core pattern works without JSON.

## Physics model extension (optional)

Resonance/resolution/background constructors (`ConstructorOfBW`, `ConstructorOfGaussian`, …)
and JSON loaders live in the `PhysicsModelsExt` package extension. Load the weak
dependencies in the same session:

```julia
using Distributions, DistributionsHEP, JSON, NumericalDistributions
using BuildConstructors

Phys = physics_models_extension()
Phys.load_prb_model_from_json("database.json", "bw", "CBpSECH", "Pol2")
```

See [`examples/2d_distribution_fit/`](examples/2d_distribution_fit/) for a nested
2D extended mixture model built with the same workflow.

## Documentation

Full API reference and tutorials (nested constructors, Optim + ComponentArrays,
Minuit2): [https://RUB-EP1.github.io/BuildConstructors.jl](https://RUB-EP1.github.io/BuildConstructors.jl)
