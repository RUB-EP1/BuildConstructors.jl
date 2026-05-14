# Optim with ComponentArrays

`ComponentArrays.jl` is a convenient bridge between named constructor metadata and
optimizers that expect array-like inputs. The objective can receive a
`ComponentArray`, access parameters by name, and still satisfy `Optim.jl` because
`ComponentArray` behaves like a vector.

This tutorial fits the nested mixture constructor from the previous tutorial.

```julia
using BuildConstructors
using ComponentArrays
using Distributions
using Optim
using Random

@with_parameters(Gauss; μ::P, σ::P, begin
    Normal(μ, σ)
end)

@with_parameters(Mixture; left, right, f_left::P, begin
    MixtureModel(
        [build_model(left, pars), build_model(right, pars)],
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
```

Generate a small toy sample:

```julia
Random.seed!(2026)
truth = MixtureModel([Normal(-1.0, 0.45), Normal(1.2, 0.35)], [0.6, 0.4])
data = rand(truth, 2_000)
```

Convert the constructor metadata to `ComponentArray`s:

```julia
start = ComponentArray(running_values(constructor))
lower = ComponentArray(running_lower_boundaries(constructor))
upper = ComponentArray(running_upper_boundaries(constructor))
```

The negative log-likelihood can pass the `ComponentArray` directly into
`build_model`. Built-in parameter descriptors use `getproperty`, so `pars.μ_left`
and `getproperty(pars, :μ_left)` work naturally.

```julia
function nll(c, data, pars)
    model = build_model(c, pars)
    return -sum(logpdf.(Ref(model), data))
end

objective(pars) = nll(constructor, data, pars)
```

Run a bounded optimization:

```julia
result = optimize(
    objective,
    lower,
    upper,
    start,
    Fminbox(LBFGS()),
)

fitted = Optim.minimizer(result)
```

`fitted` is still a `ComponentArray`, so the result stays readable:

```julia
fitted.μ_left
fitted.σ_left
fitted.f_left

update!(constructor, fitted)
running_values(constructor)
```

This avoids the usual back-and-forth conversion between a flat vector and a
`NamedTuple`. The optimizer sees an array; the model-building code sees named
parameters.
