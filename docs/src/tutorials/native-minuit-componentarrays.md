# NativeMinuit with ComponentArrays

BuildConstructors has an optional integration with
[`NativeMinuit.jl`](https://github.com/fkguo/NativeMinuit.jl): pass a constructor
as the second argument to `Minuit` and the fit configuration is read off its
free-parameter metadata. It activates once both `ComponentArrays` and
`NativeMinuit` are loaded. NativeMinuit 0.7 needs Julia 1.11 or newer; the rest of
BuildConstructors keeps its Julia 1.9 compatibility.

```julia
using BuildConstructors
using ComponentArrays
using Distributions
using NativeMinuit
using Random
import BuildConstructors: update!

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

The objective receives a `ComponentVector`. NativeMinuit 0.7 preserves the axes
through the fit, so named access works without manual index bookkeeping:

```julia
function nll(c, data, pars)
    model = build_model(c, pars)
    return -sum(logpdf.(Ref(model), data))
end

minuit = Minuit(
    pars -> nll(constructor, data, pars),
    constructor;
    errordef = 0.5,
)

migrad!(minuit)
hesse!(minuit)
```

Each NativeMinuit argument comes from one collector:

| NativeMinuit input | BuildConstructors metadata |
| --- | --- |
| `x0` | `running_values(constructor)` |
| `name` | `running_names(constructor)` |
| `error` | `running_uncertainties(constructor)`, `0.1` where none is stored |
| `limits` | `running_lower_boundaries` and `running_upper_boundaries` |

Passing any of these keywords explicitly overrides the inferred value; all other
keywords (`errordef`, `grad`, `strategy`, …) go straight to `NativeMinuit.Minuit`.

## Starting values

Starts come from the descriptor tree. To try a different starting point without
editing it, pass a `NamedTuple` that is merged over the stored values:

```julia
minuit = Minuit(
    pars -> nll(constructor, data, pars),
    constructor;
    start = (μ_left = -0.5, σ_left = 0.8),
    errordef = 0.5,
)
```

Only the keys you list are replaced; the rest stay as stored. A name that is not
a free parameter — a typo, or one that is currently fixed — raises an
`ArgumentError` instead of silently growing the fit vector.

A plain `Running` descriptor stores no value at all, so `start` is the only way
to give it one:

```julia
running_constructor = ConstructorOfGauss(
    Running("μ"),
    AdvancedParameter("σ", 1.0; boundaries = (0.05, 5.0)),
)
minuit = Minuit(
    pars -> nll(running_constructor, data, pars),
    running_constructor;
    start = (μ = -0.5,),
    errordef = 0.5,
)
```

## Fixing parameters

Fixed parameters never enter NativeMinuit's fit vector. Fix them before creating
the fit:

```julia
BuildConstructors.fix!(constructor, (:μ_left,))
minuit = Minuit(pars -> nll(constructor, data, pars), constructor; errordef = 0.5)
migrad!(minuit)
```

Both packages define `fix!` and `release!`, so keep them qualified in a session
that loads both: `BuildConstructors.fix!` changes a descriptor,
`NativeMinuit.fix!` changes a fit object. `update!` is unambiguous — BuildConstructors
does not export it, but NativeMinuit does not define it either, so the
`import BuildConstructors: update!` above is enough.

## Reading the result

NativeMinuit exposes fitted parameters by name (`minuit.values["σ_left"]`). To
write all of them back into the descriptor tree, pass the minimized fit itself to
`update!`:

```julia
minuit.valid          # check the minimization converged first
update!(constructor, minuit)
parameter_values(constructor)
```

Fixed parameters keep their stored values — they were never part of the fit.

## Why pass a constructor instead of a bare ComponentVector?

NativeMinuit accepts a `ComponentVector` starting point directly, but you still
have to assemble names, step sizes, and limits yourself, and rebuild all four
every time a parameter is fixed or released. `Minuit(objective, constructor)`
derives them from the descriptor tree on each call instead.
