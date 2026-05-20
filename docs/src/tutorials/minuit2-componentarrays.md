# Minuit2 with ComponentArrays

`Minuit2.jl` can work with `ComponentArray` inputs through the
`Optimization.jl` interface. The optimizer sees an array-like object, while the
objective can keep using named parameters.

The setup is the same as for `Optim.jl`: collect constructor metadata into
`ComponentArray`s and write the objective in terms of named parameters.

```julia
using BuildConstructors
using ComponentArrays
using Distributions
using Minuit2
using Optimization
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

Random.seed!(2026)
truth = MixtureModel([Normal(-1.0, 0.45), Normal(1.2, 0.35)], [0.6, 0.4])
data = rand(truth, 2_000)
```

Prepare the fit as a small wrapper around `OptimizationProblem`. This is the
same shape as other `Optimization.jl` solvers: the model-specific code only
defines the objective, while `problem_settings` carries solver-independent
metadata such as bounds.

```julia
function nll(c, data, pars)
    model = build_model(c, pars)
    return -sum(logpdf.(Ref(model), data))
end

function fit_minuit_nll(
    constructor,
    pars,
    data;
    minuit_settings = (strategy = 2, tolerance = 0.01, errordef = 0.5),
    optimizer_settings = (maxiters = 100,),
    problem_settings = (;),
)
    objective(pars) = nll(constructor, data, pars)
    opf = OptimizationFunction((p, x) -> objective(p))
    opp = OptimizationProblem(opf, pars; problem_settings...)
    return solve(opp, MigradOptimizer(; minuit_settings...); optimizer_settings...)
end

start = ComponentArray(running_values(constructor))
lower = ComponentArray(running_lower_boundaries(constructor))
upper = ComponentArray(running_upper_boundaries(constructor))

result = fit_minuit_nll(
    constructor,
    start,
    data;
    problem_settings = (lb = lower, ub = upper),
)
```

Use `errordef = 0.5` for a negative log-likelihood. For a chi-square objective,
use `errordef = 1.0`. Bounds are passed as `ComponentArray`s through `lb` and
`ub`; `Minuit2.jl` converts them to Minuit limits in the same parameter order as
`start`.

Because the starting point is a `ComponentArray`, the fitted values keep the same
named axes:

```julia
fitted = result.u

fitted.μ_left
fitted.σ_left
fitted.f_left

update!(constructor, fitted)
running_values(constructor)
```

The `Optimization.jl` bridge passes the bounds, but it does not currently expose
Minuit's `error` keyword. If you want to pass descriptor uncertainties as Minuit
step sizes for the initial Hessian/covariance scale, use the lower-level `Minuit`
constructor:

```julia
step = ComponentArray(map(v -> coalesce(v, 0.1), running_uncertainties(constructor)))

minuit = Minuit(
    pars -> nll(constructor, data, pars),
    start;
    limits = collect(zip(lower, upper)),
    error = collect(step),
    arraycall = true,
    errordef = 0.5,
    strategy = 2,
    tolerance = 0.01,
)

migrad!(minuit, 100)
hesse!(minuit)

update!(constructor, minuit.values)
```

The important part in both versions is that the objective function remains
written in terms of named parameters. Minuit handles the numerical vector
internally, while `ComponentArray` restores the names at the callback boundary.
