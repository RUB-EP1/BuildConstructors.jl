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

Starting values come from the descriptor tree, and there is deliberately no
`start` keyword. NativeMinuit pairs the starting vector with the names, step
sizes, and limits *by position*, so a hand-written vector combined with inferred
metadata would silently attach the wrong name and bounds to a parameter.
Inference is all-or-nothing: either the tree describes the fit completely, or you
call `NativeMinuit.Minuit` yourself and supply all four.

To move a starting point, write it into the tree first. `update!` takes a partial
`NamedTuple`, so only the parameters you name change:

```julia
update!(constructor, (μ_left = -0.5, σ_left = 0.8))
minuit = Minuit(pars -> nll(constructor, data, pars), constructor; errordef = 0.5)
```

This means every free descriptor has to store a value, which rules out `Running`
— it holds only a name, and reports its value as `missing`:

```julia
running_constructor = ConstructorOfGauss(
    Running("μ"),
    AdvancedParameter("σ", 1.0; boundaries = (0.05, 5.0)),
)
Minuit(pars -> nll(running_constructor, data, pars), running_constructor)
# ERROR: ArgumentError: (:μ,) stores no starting value
```

Use an `AdvancedParameter` or `FlexibleParameter` for such parameters, or drop to
`NativeMinuit.Minuit(fcn, x0)` with a starting vector and matching `name`,
`error`, and `limits` of your own.

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
