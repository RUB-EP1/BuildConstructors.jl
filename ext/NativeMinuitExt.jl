module NativeMinuitExt

using BuildConstructors
using ComponentArrays
using NativeMinuit

import BuildConstructors: update!
import NativeMinuit: Minuit

"""
    NativeMinuit.Minuit(fcn, constructor::AbstractConstructor; start, kwargs...)

Construct a `NativeMinuit.Minuit` fit directly from constructor metadata.

The fit contains the constructor's currently free parameters. Starting values,
names, uncertainties, and limits are inferred from the corresponding `running_*`
collectors. NativeMinuit 0.7 preserves `ComponentVector` axes through the fit, so
named property access continues to work in `build_model`.

Pass `start` as a `NamedTuple` to override selected starting values; it is merged
with `running_values(constructor)`. Parameters described only by `Running` have no
stored value, so they require this override. Missing uncertainties use
NativeMinuit's conventional step size of `0.1`.
"""
function Minuit(
    fcn,
    constructor::BuildConstructors.AbstractConstructor;
    start = nothing,
    error = nothing,
    errors = nothing,
    limits = nothing,
    grad = nothing,
    kwargs...,
)
    isempty(running_names(constructor)) && throw(ArgumentError(
        "NativeMinuit needs at least one free parameter; the constructor has none.",
    ))
    start isa Union{Nothing, NamedTuple} || throw(ArgumentError(
        "`start` must be a `NamedTuple` of parameter overrides; got $(typeof(start))",
    ))

    x0 = start === nothing ? running_values(constructor) :
         merge(running_values(constructor), start)

    missing_names = Tuple(name for name in keys(x0) if ismissing(x0[name]))
    isempty(missing_names) || throw(ArgumentError(
        "no starting value is stored for $(missing_names); pass `start` with a value " *
        "for every free parameter",
    ))
    all(value -> value isa Real, x0) || throw(ArgumentError(
        "NativeMinuit starting values must all be real numbers",
    ))

    resolved_errors = if error !== nothing
        error
    elseif errors !== nothing
        errors
    else
        Float64[ismissing(σ) ? 0.1 : σ for σ in values(running_uncertainties(constructor))]
    end

    return Minuit(
        fcn,
        ComponentVector(x0);
        name = collect(string.(running_names(constructor))),
        error = resolved_errors,
        limits = limits === nothing ?
                 collect(zip(
                     values(running_lower_boundaries(constructor)),
                     values(running_upper_boundaries(constructor)),
                 )) : limits,
        grad = grad,
        kwargs...,
    )
end

"""
    update!(constructor::AbstractConstructor, fit::NativeMinuit.Minuit)

Write the current NativeMinuit values back into matching constructor descriptors.
"""
function update!(
    constructor::BuildConstructors.AbstractConstructor,
    fit::NativeMinuit.Minuit,
)
    names = Tuple(Symbol(parameter.name) for parameter in fit.params.pars)
    values = NamedTuple{names}(Tuple(fit.values))
    update!(constructor, values)
    return nothing
end

end
