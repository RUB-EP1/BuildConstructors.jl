module NativeMinuitExt

using BuildConstructors
using ComponentArrays
using NativeMinuit

import BuildConstructors: AbstractConstructor, update!
import NativeMinuit: Minuit

# Step size for a free parameter whose descriptor stores no uncertainty
# (`Running`, `FlexibleParameter`); matches NativeMinuit's own default.
const DEFAULT_STEP = 0.1

"""
    NativeMinuit.Minuit(fcn, constructor::AbstractConstructor; kwargs...)

Set up a `NativeMinuit.Minuit` fit for the currently free parameters of
`constructor`.

The whole fit configuration is read from the descriptor tree, so fixed parameters
stay out of the fit vector:

| NativeMinuit input | source |
| --- | --- |
| `x0` | `running_values(constructor)` |
| `name` | `running_names(constructor)` |
| `error` | `running_uncertainties(constructor)`, `$DEFAULT_STEP` where none is stored |
| `limits` | `running_lower_boundaries` and `running_upper_boundaries` |

`fcn` is called with a `ComponentVector`, which `build_model` can index by
parameter name. Keywords other than `name`, `error`, and `limits` (`errordef`,
`grad`, ...) go straight to `NativeMinuit.Minuit`.

# Starting values

There is deliberately no `start` keyword. NativeMinuit pairs the starting vector
with `name`, `error`, and `limits` *by position*, so a hand-written `x0` combined
with inferred metadata would silently attach the wrong name and bounds to a
parameter. Inference is therefore all-or-nothing: either the tree describes the
fit completely, or you configure `NativeMinuit.Minuit` yourself.

To move a starting point, write it into the tree first — `update!` takes a
partial `NamedTuple`, so only the named parameters change:

```julia
update!(constructor, (σ_left = 0.8,))
minuit = Minuit(objective, constructor; errordef = 0.5)
```

This requires every free descriptor to store a value, which rules out `Running`:
it holds only a name, and `parameter_metadata` reports its value as `missing`.
Give those parameters an `AdvancedParameter` or `FlexibleParameter` instead, or
drop to `NativeMinuit.Minuit(fcn, x0)` and supply `name`, `error`, and `limits`
along with your own starting vector.
"""
function Minuit(
    fcn,
    constructor::AbstractConstructor;
    name = collect(running_names(constructor)),
    error = Float64[
        ismissing(σ) ? DEFAULT_STEP : σ for σ in running_uncertainties(constructor)
    ],
    limits = collect(
        zip(
            running_lower_boundaries(constructor),
            running_upper_boundaries(constructor),
        ),
    ),
    kwargs...,
)
    x0 = running_values(constructor)
    isempty(x0) && throw(ArgumentError(
        "the constructor has no free parameters; `release!` at least one before fitting",
    ))

    unset = Tuple(n for n in keys(x0) if !(x0[n] isa Real))
    isempty(unset) || throw(ArgumentError(
        "$unset stores no starting value; set one with `update!(constructor, pars)`, " *
        "or call `NativeMinuit.Minuit` directly with your own starting vector",
    ))

    return Minuit(fcn, ComponentVector{Float64}(x0); name, error, limits, kwargs...)
end

"""
    update!(constructor::AbstractConstructor, fit::NativeMinuit.Minuit)

Write the fit's current parameter values back into the matching descriptors.
"""
function update!(constructor::AbstractConstructor, fit::Minuit)
    update!(constructor, NamedTuple{Symbol.(fit.parameters)}(Tuple(fit.values)))
    return nothing
end

end
