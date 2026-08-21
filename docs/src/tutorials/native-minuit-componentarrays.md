# NativeMinuit with ComponentArrays

BuildConstructors has an optional integration with
[`NativeMinuit.jl`](https://github.com/fkguo/NativeMinuit.jl). Pass a constructor
as the second argument to `Minuit` and the fit configuration is inferred from its
free-parameter metadata. NativeMinuit 0.7 currently requires Julia 1.11 or newer;
the rest of BuildConstructors retains its Julia 1.9 compatibility.

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

The adapter obtains the following NativeMinuit arguments automatically:

| NativeMinuit input | BuildConstructors metadata |
| --- | --- |
| values | `running_values(constructor)` |
| names | `running_names(constructor)` |
| errors | `running_uncertainties(constructor)` |
| limits | `running_lower_boundaries` and `running_upper_boundaries` |

An uncertainty of `missing` uses a step size of `0.1`. By default, starting
values come from `running_values(constructor)`. In the setup above, that already
includes `σ_left = 1.0` together with the other free parameters.

To try a different starting point without editing the descriptor tree, pass a
`NamedTuple` override. It is merged with the stored starts from the constructor:

```julia
minuit = Minuit(
    pars -> nll(constructor, data, pars),
    constructor;
    start = (σ_left = 0.8,),
    errordef = 0.5,
)
```

Only the named keys you supply are replaced. Here, `σ_left` changes from `1.0` to
`0.8`; all other starts stay as stored.

A plain `Running` descriptor has no stored starting value. Supply it through
`start`:

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

When several parameters need overrides, list them in the same `NamedTuple`:

```julia
minuit = Minuit(
    pars -> nll(constructor, data, pars),
    constructor;
    start = (μ_left = -0.5, σ_left = 0.8, f_left = 0.4),
    errordef = 0.5,
)
```

Constructor-level fixed parameters never enter NativeMinuit's fit vector. Fix
them before creating the fit:

```julia
BuildConstructors.fix!(constructor, (:μ_left,))
minuit = Minuit(pars -> nll(constructor, data, pars), constructor; errordef = 0.5)
```

BuildConstructors deliberately does not export the common mutation names
`fix!`, `release!`, and `update!`. Qualify `BuildConstructors.fix!` as above (or
import it explicitly) when changing descriptors; use `NativeMinuit.fix!` when
changing a NativeMinuit fit object.

NativeMinuit exposes fitted parameters by name (`minuit.values["σ_left"]`). To
write all fitted values back into the descriptor tree, pass the fit directly to
`update!`:

```julia
update!(constructor, minuit)
parameter_values(constructor)
```

## Why pass a constructor instead of a bare ComponentVector?

NativeMinuit accepts a `ComponentVector` starting point directly, but you still
need to assemble names, errors, and limits yourself. `Minuit(objective,
constructor)` infers all of that from the descriptor tree and keeps fixed
parameters out of the fit vector automatically.
