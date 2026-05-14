# BuildConstructors.jl

`BuildConstructors.jl` is a small pattern for building Julia objects whose numerical
parameters need extra metadata: defaults, fixed/free state, bounds, uncertainties,
or names used by a fitting backend.

Trying to attach that metadata directly to user objects usually hits a wall. Some
objects are immutable, some come from another package, some have no natural place
for a default value, and some are not even parameterized in the way your workflow
needs. The part that always works is to wrap the object construction instead:

1. Store parameter descriptors in a constructor object.
2. Collect or update the running parameters from that constructor.
3. Call `build_model(constructor, pars)` to create the real object.

The wrapped object can be anything: a distribution, a model, a callable, a nested
composition, or a domain-specific type from another package. `BuildConstructors.jl`
does not impose a dimensionality, a call signature, or a model interface. Those
choices stay with you.

## Installation

```julia
using Pkg
Pkg.add("BuildConstructors")
```

## Essential vs Optional

The essential pattern is small:

1. Use parameter descriptors such as `Fixed`, `Running`, or your own
   `AbstractParameter` subtype.
2. Store those descriptors in an `AbstractConstructor`.
3. Implement `build_model(constructor, pars)`.

Everything else is convenience:

| Layer | Essential? | Why it exists |
| --- | --- | --- |
| `Fixed`, `Running`, `FlexibleParameter`, `AdvancedParameter` | Useful defaults | Common descriptor types for fixed/free parameters, defaults, bounds, and uncertainties. |
| `running_values`, `fix!`, `release!`, `update!` | Convenience | Recursive tools for collecting and mutating metadata in nested constructors. |
| `@with_parameters` | Convenience | Generates struct + `build_model` from a field list ended by **`binder ->`** (typically `pars -> begin ... end`). |
| `serialize` / `deserialize` / `register!` | Optional | Save and restore constructor descriptions through JSON or database-like workflows. |
| PRB model constructors and loaders | Optional example | Domain-specific probability-model utilities built with the same general mechanism. |

If your object already has a perfect home for metadata, you may not need this
package. It becomes useful when the object should remain clean, external,
immutable, or domain-native, but your workflow still needs to know which numbers
are fixed, running, bounded, initialized, or serializable.

## Basic Idea

Parameters are represented by small descriptor objects. A descriptor decides how a
numerical value is obtained when the real model is built.

```julia
using BuildConstructors

Fixed(1.0)        # always evaluates to 1.0
Running("scale")  # reads `scale` from the supplied parameter values
```

A constructor stores these descriptors instead of storing the numerical values
directly:

```julia
using Distributions

struct ConstructorOfNormalModel{T1<:BuildConstructors.AbstractParameter,
                                T2<:BuildConstructors.AbstractParameter} <:
       BuildConstructors.AbstractConstructor
    description_of_μ::T1
    description_of_σ::T2
end

function BuildConstructors.build_model(c::ConstructorOfNormalModel, pars)
    μ = BuildConstructors.value(c.description_of_μ; pars)
    σ = BuildConstructors.value(c.description_of_σ; pars)
    return Normal(μ, σ)
end

c = ConstructorOfNormalModel(Fixed(0.0), Running("σ"))

running_values(c)        # (σ = missing,)
model = build_model(c, (σ = 0.2,))
```

This keeps the user object clean. `Normal(0.0, 0.2)` does not need to know that
`σ` was called `"σ"`, was free in a fit, had a starting value, or came from a JSON
file. The constructor knows that, and the final object stays exactly the object you
wanted to build.

## Parameter Descriptors

The package includes a few ready-to-use descriptors:

| Descriptor | Use |
| --- | --- |
| `Fixed(value)` | A constant value that is not collected as a running parameter. |
| `Running(name)` | A free parameter read from `pars` by name. |
| `FlexibleParameter(name, value)` | A parameter with a stored value that can be fixed or released. |
| `AdvancedParameter(name, value; boundaries, uncertainty)` | A parameter with a stored value, bounds, uncertainty, and fixed/free state. |

The same generic tools work recursively on constructors and nested constructors:

```julia
running_values(c)
running_uncertainties(c)
running_lower_boundaries(c)
running_upper_boundaries(c)

fix!(c, (:σ,))
release!(c, (:σ,))
update!(c, (σ = 0.25,))
```

You can define your own parameter descriptor by subtyping
`BuildConstructors.AbstractParameter` and implementing `BuildConstructors.value`.
Implement the other methods only if your descriptor needs to participate in fixing,
releasing, updating, or collection of metadata.

## The `build_model` Convention

The main convention is:

```julia
build_model(constructor, pars)
```

`pars` is deliberately unconstrained. It can be a `NamedTuple`, a
`ComponentArray`, or any object your parameter descriptors know how to read.
Likewise, `build_model` can return any Julia object. This is the central design
choice of the package: the constructor carries metadata and assembly logic, while
your returned object remains domain-native.

Nested construction is just ordinary Julia:

```julia
struct ConstructorOfScaled{C,T<:BuildConstructors.AbstractParameter} <:
       BuildConstructors.AbstractConstructor
    child::C
    description_of_scale::T
end

function BuildConstructors.build_model(c::ConstructorOfScaled, pars)
    child = build_model(c.child, pars)
    scale = BuildConstructors.value(c.description_of_scale; pars)
    return x -> scale * child(x)
end
```

Because the metadata collection methods walk over fields of
`AbstractConstructor`s, running parameters inside `child` are collected together
with `scale`.

## Less Boilerplate With `@with_parameters`

For many simple wrappers, the `@with_parameters` macro generates the constructor type and `build_model` method for you. The macro call has:

1. The model name, e.g. `Gauss`.
2. A comma-separated field list after the semicolon (`field`, `field::P`, or `field::SomeType`; see below).
3. A **unary lambda** as the last item: **`binder -> expr`** or **`binder -> begin ... end`**.

`binder` is the local name for the generated `build_model` second argument. By convention it is **`pars`** (matching the `value(...; pars)` keyword elsewhere), but `θ`, `p`, or any unused symbol works. Use a plain symbol — **never** annotate it (`θ::NamedTuple`). Runtime parameter values may be named tuples, `ComponentArray`s, or anything else your descriptors support.

Minimal example (`pars ->` convention):

```julia
using BuildConstructors
using Distributions

@with_parameters(Gauss; μ::P, σ::P, pars -> begin
    Normal(μ, σ)
end)

c = ConstructorOfGauss(Fixed(0.0), Running("σ"))
model = build_model(c, (σ = 0.2,))
```

Same method with another binder name:

```julia
@with_parameters(Gauss; μ::P, σ::P, θ -> begin
    Normal(μ, σ)  # `build_model` is lowered as `(_, θ)`, nested calls use `(child, θ)`
end)
```

The generated type is `ConstructorOf{Name}` (here `ConstructorOfGauss`). For `field::P`, structs store **`description_of_field`**; numeric values are injected before the RHS of the arrow via `BuildConstructors.value(...; pars = binder)`. For typed or parametric slots, bindings are **`field = c.field`**.

Field forms:

| Form | Meaning |
| --- | --- |
| `field::P` | Parameter descriptor → resolved numeric `field` inside the RHS. |
| `field::SomeType` | Constant slot → bare `field` from the constructor instance. |
| `field` | Parametric slot (nested constructors, etc.) → bare `field`. |

Scaled wrapper:

```julia
@with_parameters(Scaled; child, scale::P, pars -> begin
    child_model = build_model(child, pars)
    x -> scale * child_model(x)
end)
```

```julia
c = ConstructorOfScaled(child_constructor, Running("scale"))
```

Field reordering in generated constructors (stable): plain parametric fields first, then `::P` descriptors, then typed constants. Mixed declaration:

```julia
@with_parameters(Windowed; model, μ::P, support::Tuple{Float64,Float64}, pars -> begin
    truncated(build_model(model, pars), support[1] + μ, support[2] + μ)
end)
```

```julia
ConstructorOfWindowed(model, μ_descriptor, support)
```

Bare `begin ... end` without `pars ->` is **not** accepted; always write **one unary lambda** last.

Use the macro when that generated shape is clear and useful. Write the constructor
and `build_model` by hand when you need a custom field order, extra validation,
special constructors, or a more explicit API.

## Serialization

Serialization is useful when constructor descriptions need to move through files,
databases, or fitting pipelines. The package provides `serialize` and `deserialize`
methods for its built-in descriptors and included example constructors. Custom
types can participate by defining their own methods and registering the type:

```julia
BuildConstructors.register!(ConstructorOfMyModel)
```

Serialization is a bonus layer on top of the core pattern. You can use
constructors, parameter collection, `fix!`, `release!`, `update!`, and
`build_model` without using JSON at all.

## Included Examples

The repository includes several constructors for probability-model workflows,
including the physical-resolution-background composition used in the original
application. They are examples of the same general mechanism rather than a
restriction on what the package can build.

These examples and JSON/database helpers live in the `PhysicsModelsExt` package
extension. Install the weak dependencies in addition to `BuildConstructors` when
you want constructors such as `ConstructorOfBW`, `ConstructorOfGaussian`, or
`load_prb_model_from_json`:

```julia
using Pkg
Pkg.add([
    "Distributions",
    "DistributionsHEP",
    "JSON",
    "NumericalDistributions",
])
```

Then load the extension dependencies before using the physics helpers:

```julia
using Distributions, DistributionsHEP, JSON, NumericalDistributions
using BuildConstructors

Phys = BuildConstructors.physics_models_extension()
```
