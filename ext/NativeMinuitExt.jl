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
    NativeMinuit.Minuit(fcn, constructor::AbstractConstructor; start = (;), kwargs...)

Set up a `NativeMinuit.Minuit` fit for the currently free parameters of
`constructor`.

Names, starting values, step sizes, and limits are read from the `running_*`
collectors, so fixed parameters stay out of the fit vector. `fcn` is called with
a `ComponentVector`, which `build_model` can index by parameter name.

`start` is a `NamedTuple` of starting-value overrides merged over
`running_values(constructor)`; parameters described by `Running` have no stored
value and must be listed there. Passing `name`, `error`, or `limits` explicitly
replaces the inferred one, and every other keyword (`errordef`, `grad`, ...) goes
straight to `NativeMinuit.Minuit`.
"""
function Minuit(
    fcn,
    constructor::AbstractConstructor;
    start::NamedTuple = (;),
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
    free = running_names(constructor)
    isempty(free) && throw(ArgumentError(
        "the constructor has no free parameters; `release!` at least one before fitting",
    ))

    unknown = setdiff(keys(start), free)
    isempty(unknown) || throw(ArgumentError(
        "`start` names $(Tuple(unknown)), which are not free parameters of the " *
        "constructor; the free ones are $free",
    ))

    x0 = merge(running_values(constructor), start)
    unset = Tuple(n for n in free if !(x0[n] isa Real))
    isempty(unset) || throw(ArgumentError(
        "no starting value stored for $unset; pass one, e.g. `start = ($(first(unset)) = 0.0,)`",
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
