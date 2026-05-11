
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# very simple parameters
"""
    Fixed(value)

Parameter descriptor that always resolves to the stored numeric `value`.

`Fixed` parameters are intentionally absent from `running_values` and related
metadata collectors, because they are not expected to be supplied by a fitting or
optimization backend.
"""
struct Fixed <: AbstractParameter
    value::Float64
end

"""
    value(parameter; pars)

Resolve a parameter descriptor to the numeric value used by `build_model`.

Built-in descriptors either ignore `pars` (`Fixed`) or read a value from it
(`Running`, `FlexibleParameter`, `AdvancedParameter`). Custom descriptors should
implement this method when introducing a new way to obtain parameter values.
"""
value(p::Fixed; pars) = p.value
# other methods are default -- nothing


"""
    Running(name)

Parameter descriptor for a free parameter read from `pars` by name.

For example, `Running("σ")` resolves with `getproperty(pars, :σ)`. It is collected
by `running_values` with a `missing` value, signalling that no default is stored
inside the descriptor.
"""
struct Running <: AbstractParameter
    name::String
end

"""
    value(p::Running; pars)

Resolve a running parameter by reading `Symbol(p.name)` from `pars`.
"""
value(p::Running; pars) = getproperty(pars, Symbol(p.name))

"""
    running_values(p::Running)

Return a one-entry `NamedTuple` for the running parameter name, with `missing` as
the value because `Running` stores no default.
"""
running_values(c::Running) = NamedTuple{(Symbol(c.name),)}((missing,))

"""
    running_uncertainties(p::Running)

Return `missing` uncertainty metadata for a plain `Running` parameter.
"""
running_uncertainties(p::Running) = NamedTuple{(Symbol(p.name),)}((missing,))

"""
    running_upper_boundaries(p::Running)

Return `Inf` as the default upper boundary for a plain `Running` parameter.
"""
running_upper_boundaries(c::Running) = NamedTuple{(Symbol(c.name),)}((Inf,))

"""
    running_lower_boundaries(p::Running)

Return `-Inf` as the default lower boundary for a plain `Running` parameter.
"""
running_lower_boundaries(c::Running) = NamedTuple{(Symbol(c.name),)}((-Inf,))


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# mutable parameter, can be fixed and released
"""
    FlexibleParameter(name, value[, fixed])

Mutable parameter descriptor with a stored value and fixed/free state.

When free, it resolves from `pars` just like `Running`. When fixed, it resolves to
its stored value. Use `fix!`, `release!`, and `update!` to mutate the state and
stored value in-place.
"""
mutable struct FlexibleParameter <: AbstractParameter
    name::String
    value::Float64
    fixed::Bool
end

"""
    value(p::FlexibleParameter; pars)

Resolve to the stored value when `p.fixed` is true; otherwise read `p.name` from
`pars`.
"""
value(p::FlexibleParameter; pars) = p.fixed ? p.value : getproperty(pars, Symbol(p.name))

"""
    FlexibleParameter(name, value)

Create a free `FlexibleParameter` with a stored starting value.
"""
FlexibleParameter(name, value) = FlexibleParameter(name, value, false)

"""
    fix!(p::FlexibleParameter, par_names)

Set `p.fixed = true` when `Symbol(p.name)` is present in `par_names`.
"""
fix!(p::FlexibleParameter, par_names) =
    Symbol(p.name) ∈ par_names ? setfield!(p, :fixed, true) : nothing

"""
    release!(p::FlexibleParameter, par_names)

Set `p.fixed = false` when `Symbol(p.name)` is present in `par_names`.
"""
release!(p::FlexibleParameter, par_names) =
    Symbol(p.name) ∈ par_names ? setfield!(p, :fixed, false) : nothing

"""
    update!(p::FlexibleParameter, pars)

Replace the stored value with `pars[p.name]` when that name is present.
"""
update!(c::FlexibleParameter, pars) =
    Symbol(c.name) ∈ keys(pars) ? setfield!(c, :value, getproperty(pars, Symbol(c.name))) :
    nothing

"""
    running_values(p::FlexibleParameter)

Return the stored value for this parameter, whether it is currently fixed or free.
"""
running_values(c::FlexibleParameter) = NamedTuple{(Symbol(c.name),)}((c.value,))

"""
    running_uncertainties(p::FlexibleParameter)

Return `missing` uncertainty metadata for a flexible parameter.
"""
running_uncertainties(p::FlexibleParameter) = NamedTuple{(Symbol(p.name),)}((missing,))

"""
    running_upper_boundaries(p::FlexibleParameter)

Return `Inf` as the default upper boundary for a flexible parameter.
"""
running_upper_boundaries(p::FlexibleParameter) = NamedTuple{(Symbol(p.name),)}((Inf,))

"""
    running_lower_boundaries(p::FlexibleParameter)

Return `-Inf` as the default lower boundary for a flexible parameter.
"""
running_lower_boundaries(p::FlexibleParameter) = NamedTuple{(Symbol(p.name),)}((-Inf,))



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# advanced parameter, can be fixed and released, and has boundaries and uncertainty
"""
    AdvancedParameter(name, value; boundaries = (-Inf, Inf), uncertainty = 1.0)
    AdvancedParameter(name, value, boundaries, uncertainty, fixed)

Mutable parameter descriptor with stored value, bounds, uncertainty, and
fixed/free state.

Like `FlexibleParameter`, it resolves from `pars` while free and from its stored
value while fixed. The extra metadata is returned by the corresponding
`running_*` collection functions.
"""
mutable struct AdvancedParameter <: AbstractParameter
    name::String
    value::Float64
    boundaries::Tuple{Float64,Float64}
    uncertainty::Float64
    fixed::Bool
end

"""
    value(p::AdvancedParameter; pars)

Resolve to the stored value when `p.fixed` is true; otherwise read `p.name` from
`pars`.
"""
value(p::AdvancedParameter; pars) = p.fixed ? p.value : getproperty(pars, Symbol(p.name))

"""
    AdvancedParameter(name, value; boundaries = (-Inf, Inf), uncertainty = 1.0)

Create a free `AdvancedParameter` with stored value, bounds, and uncertainty.
"""
AdvancedParameter(name, value; boundaries = (-Inf, Inf), uncertainty = 1.0) =
    AdvancedParameter(name, value, boundaries, uncertainty, false)

"""
    fix!(p::AdvancedParameter, par_names)

Set `p.fixed = true` when `Symbol(p.name)` is present in `par_names`.
"""
fix!(p::AdvancedParameter, par_names) =
    Symbol(p.name) ∈ par_names ? setfield!(p, :fixed, true) : nothing

"""
    release!(p::AdvancedParameter, par_names)

Set `p.fixed = false` when `Symbol(p.name)` is present in `par_names`.
"""
release!(p::AdvancedParameter, par_names) =
    Symbol(p.name) ∈ par_names ? setfield!(p, :fixed, false) : nothing

"""
    update!(p::AdvancedParameter, pars)

Replace the stored value with `pars[p.name]` when that name is present.
"""
update!(c::AdvancedParameter, pars) =
    Symbol(c.name) ∈ keys(pars) ? setfield!(c, :value, getproperty(pars, Symbol(c.name))) :
    nothing

"""
    running_values(p::AdvancedParameter)

Return the stored value for this parameter.
"""
running_values(c::AdvancedParameter) = NamedTuple{(Symbol(c.name),)}((c.value,))

"""
    running_uncertainties(p::AdvancedParameter)

Return the stored uncertainty for this parameter.
"""
running_uncertainties(p::AdvancedParameter) =
    NamedTuple{(Symbol(p.name),)}((p.uncertainty,))

"""
    running_upper_boundaries(p::AdvancedParameter)

Return the upper boundary stored in `p.boundaries[2]`.
"""
running_upper_boundaries(p::AdvancedParameter) =
    NamedTuple{(Symbol(p.name),)}((p.boundaries[2],))

"""
    running_lower_boundaries(p::AdvancedParameter)

Return the lower boundary stored in `p.boundaries[1]`.
"""
running_lower_boundaries(p::AdvancedParameter) =
    NamedTuple{(Symbol(p.name),)}((p.boundaries[1],))
