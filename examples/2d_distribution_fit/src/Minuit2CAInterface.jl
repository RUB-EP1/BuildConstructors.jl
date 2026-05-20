module Minuit2CAInterface

using ComponentArrays
using ComponentArrays: getaxes
using Minuit2

import Base: minimum

export Minuit2CA
export Minuit2CAResult
export optimize
export minimizer
export minimum
export converged
export original
export hesse!

Base.@kwdef struct Minuit2CA
    strategy::Int = 1
    tolerance::Float64 = 0.1
    errordef::Float64 = 1.0
    maxcalls::Int = 0
    errors::Any = nothing
    lower::Any = nothing
    upper::Any = nothing
    limits::Any = nothing
    fixed::Any = nothing
    names::Any = nothing
    grad::Any = nothing
    precision::Any = nothing
    run_hesse::Bool = false
    hesse_strategy::Int = strategy
    hesse_maxcalls::Int = 0
    migrad_iterate::Int = 5
    migrad_use_simplex::Bool = true
end

struct Minuit2CAResult{T, M}
    minimizer::T
    minimum::Float64
    original::M
    converged::Bool
    iterations::Int
    objective_calls::Int
    edm::Float64
    valid::Bool
    reached_call_limit::Bool
    above_max_edm::Bool
end

minimizer(result::Minuit2CAResult) = result.minimizer
minimum(result::Minuit2CAResult) = result.minimum
converged(result::Minuit2CAResult) = result.converged
original(result::Minuit2CAResult) = result.original

function hesse!(result::Minuit2CAResult; strategy::Int = 1, maxcalls::Int = 0)
    Minuit2.hesse!(original(result); strategy, maxcalls)
    return result
end

function Base.show(io::IO, result::Minuit2CAResult)
    print(
        io,
        "Minuit2CAResult(minimum = $(result.minimum), converged = $(result.converged), ",
        "calls = $(result.objective_calls), edm = $(result.edm))",
    )
end

function optimize(objective, initial::ComponentArray, settings::Minuit2CA = Minuit2CA())
    minuit = Minuit(objective, initial; _minuit_keywords(initial, settings)...)
    migrad!(
        minuit,
        settings.strategy;
        ncall = settings.maxcalls,
        iterate = settings.migrad_iterate,
        use_simplex = settings.migrad_use_simplex,
    )
    if settings.run_hesse
        hesse!(minuit; strategy = settings.hesse_strategy, maxcalls = settings.hesse_maxcalls)
    end
    values = ComponentArray(collect(minuit.values), getaxes(minuit.values))
    return Minuit2CAResult(
        values,
        minuit.fval,
        minuit,
        minuit.is_valid && !minuit.has_reached_call_limit && !minuit.is_above_max_edm,
        Int(minuit.niter),
        Int(minuit.nfcn),
        minuit.edm,
        minuit.is_valid,
        minuit.has_reached_call_limit,
        minuit.is_above_max_edm,
    )
end

function _minuit_keywords(initial, settings::Minuit2CA)
    kwargs = Dict{Symbol, Any}(
        :arraycall => true,
        :errordef => settings.errordef,
        :tolerance => settings.tolerance,
        :strategy => settings.strategy,
    )

    names = isnothing(settings.names) ? _default_names(initial) : collect(settings.names)
    kwargs[:names] = string.(names)

    !isnothing(settings.errors) && (kwargs[:error] = collect(settings.errors))
    !isnothing(settings.fixed) && (kwargs[:fixed] = collect(settings.fixed))
    !isnothing(settings.grad) && (kwargs[:grad] = settings.grad)
    !isnothing(settings.precision) && (kwargs[:precision] = settings.precision)

    limits = _limits(settings, length(initial))
    !isnothing(limits) && (kwargs[:limits] = limits)

    _check_length(kwargs[:names], length(initial), "names")
    haskey(kwargs, :error) && _check_length(kwargs[:error], length(initial), "errors")
    haskey(kwargs, :fixed) && _check_length(kwargs[:fixed], length(initial), "fixed")
    haskey(kwargs, :limits) && _check_length(kwargs[:limits], length(initial), "limits")
    return kwargs
end

function _default_names(initial::ComponentArray)
    names = collect(keys(initial))
    length(names) == length(initial) && return names
    return [Symbol(:p, i) for i in 1:length(initial)]
end

function _limits(settings::Minuit2CA, npars)
    if !isnothing(settings.limits)
        return collect(settings.limits)
    end
    isnothing(settings.lower) && isnothing(settings.upper) && return nothing
    lower = isnothing(settings.lower) ? fill(-Inf, npars) : collect(settings.lower)
    upper = isnothing(settings.upper) ? fill(Inf, npars) : collect(settings.upper)
    return collect(zip(lower, upper))
end

function _check_length(values, expected, label)
    length(values) == expected && return nothing
    throw(ArgumentError("Minuit2CA $(label) length $(length(values)) does not match parameter length $(expected)"))
end

end
