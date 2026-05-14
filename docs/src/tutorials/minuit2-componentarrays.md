# Minuit2 with ComponentArrays

`Minuit2.jl` can also work with `ComponentArray` inputs. Its public API documents
the `componentarray_axes` mechanism used to reconstruct a `ComponentArray` from
the vector passed through the Minuit callback. When the starting point is a
`ComponentArray`, Minuit2 can infer those axes and call the objective with named
parameters.

The mixture setup matches the [Nested Constructors](@ref)
tutorial (`other_pars -> begin ... end` syntax).

```julia
using BuildConstructors
using ComponentArrays
using Distributions
using Minuit2
using Random

@with_parameters(Gauss; μ::P, σ::P, other_pars -> begin
    Normal(μ, σ)
end)

@with_parameters(Mixture; left, right, f_left::P, other_pars -> begin
    MixtureModel(
        [build_model(left, other_pars), build_model(right, other_pars)],
        [f_left, 1 - f_left],
    )
end)

constructor = ConstructorOfMixture(
    ConstructorOfGauss(
        AdvancedParameter("μ_left", -0.5; boundaries = (-5.0, 5.0), uncertainty = 0.1),
        AdvancedParameter("σ_left", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.05),
    ),
    ConstructorOfGauss(
        AdvancedParameter("μ_right", 0.7; boundaries = (-5.0, 5.0), uncertainty = 0.1),
        AdvancedParameter("σ_right", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.05),
    ),
    AdvancedParameter("f_left", 0.5; boundaries = (0.0, 1.0), uncertainty = 0.02),
)

Random.seed!(2026)
truth = MixtureModel([Normal(-1.0, 0.45), Normal(1.2, 0.35)], [0.6, 0.4])
data = rand(truth, 2_000)
```

Prepare the starting point and metadata:

```julia
start = ComponentArray(running_values(constructor))
lower = ComponentArray(running_lower_boundaries(constructor))
upper = ComponentArray(running_upper_boundaries(constructor))

errors = ComponentArray(
    map(v -> coalesce(v, 0.1), running_uncertainties(constructor)),
)
limits = collect(zip(lower, upper))
```

The `coalesce` call gives Minuit a finite step size even if a descriptor has no
stored uncertainty and reports `missing`.

```julia
function nll(c, data, pars)
    model = build_model(c, pars)
    return -sum(logpdf.(Ref(model), data))
end

objective(pars) = nll(constructor, data, pars)
```

Create and run Minuit:

```julia
minuit = Minuit(
    objective,
    start;
    names = string.(keys(start)),
    limits = limits,
    error = collect(errors),
    arraycall = true,
    errordef = 0.5,
)

migrad!(minuit)
hesse!(minuit)
```

Use `errordef = 0.5` for a negative log-likelihood. For a chi-square objective,
use `errordef = 1.0`.

With a `ComponentArray` starting point, `minuit.values` keeps the same named axes:

```julia
fitted = minuit.values

fitted.μ_left
fitted.σ_left
fitted.f_left

update!(constructor, fitted)
running_values(constructor)
```

The important part is that the objective function itself can remain written in
terms of named parameters. Minuit handles the numerical vector internally, while
`ComponentArray` restores the names at the callback boundary.
