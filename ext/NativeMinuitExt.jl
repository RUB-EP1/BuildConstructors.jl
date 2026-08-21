module NativeMinuitExt

using BuildConstructors
using ComponentArrays
using NativeMinuit

import BuildConstructors: update!
import NativeMinuit: Minuit

function _named_start(constructor, start)
    names = running_names(constructor)
    isempty(names) && throw(ArgumentError(
        "NativeMinuit needs at least one free parameter; the constructor has none.",
    ))

    values = if start === nothing
        running_values(constructor)
    elseif start isa ComponentArray
        missing_names = filter(name -> !hasproperty(start, name), names)
        isempty(missing_names) || throw(ArgumentError(
            "start is missing constructor parameters $(Tuple(missing_names))",
        ))
        NamedTuple{names}(Tuple(getproperty(start, name) for name in names))
    elseif start isa AbstractVector
        length(start) == length(names) || throw(DimensionMismatch(
            "start has $(length(start)) values, but the constructor has " *
            "$(length(names)) free parameters",
        ))
        NamedTuple{names}(Tuple(start))
    else
        missing_names = filter(name -> !hasproperty(start, name), names)
        isempty(missing_names) || throw(ArgumentError(
            "start is missing constructor parameters $(Tuple(missing_names))",
        ))
        NamedTuple{names}(Tuple(getproperty(start, name) for name in names))
    end

    missing_names = Tuple(name for name in names if ismissing(getproperty(values, name)))
    isempty(missing_names) || throw(ArgumentError(
        "no starting value is stored for $(missing_names); pass `start` with a value " *
        "for every free parameter",
    ))
    all(value -> value isa Real, values) || throw(ArgumentError(
        "NativeMinuit starting values must all be real numbers",
    ))
    return ComponentVector(values)
end

function _default_errors(constructor)
    return Float64[
        ismissing(error) ? 0.1 : error for error in values(running_uncertainties(constructor))
    ]
end

function _default_limits(constructor)
    lower = values(running_lower_boundaries(constructor))
    upper = values(running_upper_boundaries(constructor))
    return collect(zip(lower, upper))
end

function _resolved_names(constructor, name, names)
    expected = collect(string.(running_names(constructor)))
    supplied = name === nothing ? names : name
    if supplied !== nothing && String.(supplied) != expected
        throw(ArgumentError(
            "NativeMinuit parameter names must match the constructor order $expected; " *
            "got $(String.(supplied))",
        ))
    end
    return expected
end

"""
    NativeMinuit.Minuit(fcn, constructor::AbstractConstructor; start, kwargs...)

Construct a `NativeMinuit.Minuit` fit directly from constructor metadata.

The fit contains the constructor's currently free parameters. Starting values,
names, uncertainties, and limits are inferred from the corresponding `running_*`
collectors. NativeMinuit 0.7 preserves `ComponentVector` axes through the fit, so
named property access continues to work in `build_model`.

Pass `start` to override stored starting values. Parameters described only by
`Running` have no stored value, so they require this override. Missing
uncertainties use NativeMinuit's conventional step size of `0.1`.
"""
function Minuit(
    fcn,
    constructor::BuildConstructors.AbstractConstructor;
    start = nothing,
    name = nothing,
    names = nothing,
    error = nothing,
    errors = nothing,
    limits = nothing,
    grad = nothing,
    kwargs...,
)
    start_ca = _named_start(constructor, start)

    resolved_names = _resolved_names(constructor, name, names)
    resolved_errors = error === nothing ?
                      (errors === nothing ? _default_errors(constructor) : errors) : error
    resolved_limits = limits === nothing ? _default_limits(constructor) : limits

    return Minuit(
        fcn,
        start_ca;
        name = resolved_names,
        error = resolved_errors,
        limits = resolved_limits,
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
