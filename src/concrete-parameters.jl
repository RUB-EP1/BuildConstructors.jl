
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# very simple parameters
"""
    Fixed(value)

Parameter descriptor that always resolves to the stored numeric `value`.

`Fixed` parameters are intentionally absent from `parameter_values` and related
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
by `parameter_values` with a `missing` value, signalling that no default is stored
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
    parameter_metadata(p::Running)

Return metadata for a plain running parameter.
"""
parameter_metadata(c::Running) = _parameter_metadata_entry(c; name = c.name, value = missing)

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
function update!(c::FlexibleParameter, pars)
    sym = Symbol(c.name)
    hasproperty(pars, sym) && (c.value = getproperty(pars, sym))
    return nothing
end

"""
    parameter_metadata(p::FlexibleParameter)

Return metadata for a flexible parameter, including its fixed/free state.
"""
parameter_metadata(c::FlexibleParameter) =
    _parameter_metadata_entry(c; name = c.name, value = c.value, fixed = c.fixed)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# advanced parameter, can be fixed and released, and has boundaries and uncertainty
"""
    AdvancedParameter(name, value; boundaries = (-Inf, Inf), uncertainty = 1.0)
    AdvancedParameter(name, value, boundaries, uncertainty, fixed)

Mutable parameter descriptor with stored value, bounds, uncertainty, and
fixed/free state.

Like `FlexibleParameter`, it resolves from `pars` while free and from its stored
value while fixed. The extra metadata is returned by the corresponding
`parameter_*` collection functions.
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
function update!(c::AdvancedParameter, pars)
    sym = Symbol(c.name)
    hasproperty(pars, sym) && (c.value = getproperty(pars, sym))
    return nothing
end

"""
    parameter_metadata(p::AdvancedParameter)

Return metadata for an advanced parameter, including bounds, uncertainty, and
fixed/free state.
"""
parameter_metadata(c::AdvancedParameter) = _parameter_metadata_entry(
    c;
    name = c.name,
    value = c.value,
    uncertainty = c.uncertainty,
    lower = c.boundaries[1],
    upper = c.boundaries[2],
    fixed = c.fixed,
)

