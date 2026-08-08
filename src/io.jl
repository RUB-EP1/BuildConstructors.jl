# Built-in parameter types are always resolvable by name.
register!(Fixed)
register!(Running)
register!(FlexibleParameter)
register!(AdvancedParameter)

_type_name(::Type{T}) where {T} = string(nameof(T))

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

"""
    serialize(constructor_or_parameter; pars=NamedTuple())

Convert a parameter descriptor or constructor into a dictionary-like object.

The result is a **snapshot** of the constructor tree together with parameter
values — not the tree alone. Every parameter field is written with a numeric
value (`"value"` or `"starting_value"`) so the dict can be restored and passed
to [`build_model`](@ref).

Fixed/free status does not affect serialization. Numbers come from `pars`
when a matching name is supplied, otherwise from the stored field on the
descriptor (see [`update!`](@ref)). Typical workflow after a fit:
`update!(constructor, fitted)` then `serialize(constructor)`.

How each descriptor type obtains the stored number:

- [`Fixed`](@ref) — from the descriptor; `pars` ignored.
- [`Running`](@ref) — from `pars` only (no stored default; must be supplied).
- [`FlexibleParameter`](@ref) / [`AdvancedParameter`](@ref) — `pars[name]` when
  present, otherwise the stored `.value`.

Serialization is optional: the core constructor pattern works without it, but
these methods are useful when descriptions need to be saved to JSON or a database.
"""
function _serialized_value(c::Running; pars)
    sym = Symbol(c.name)
    hasproperty(pars, sym) ||
        error("serialize($(typeof(c))): `pars` must contain $(repr(c.name))")
    return getproperty(pars, sym)
end

_serialized_value(c::Union{FlexibleParameter,AdvancedParameter}; pars) =
    hasproperty(pars, Symbol(c.name)) ? getproperty(pars, Symbol(c.name)) : c.value

serialize(c::Fixed; pars=NamedTuple()) = LittleDict("type" => "Fixed", "value" => c.value)

serialize(c::Running; pars=NamedTuple()) = LittleDict(
    "type" => "Running",
    "name" => c.name,
    "starting_value" => _serialized_value(c; pars),
)

serialize(c::FlexibleParameter; pars=NamedTuple()) = LittleDict(
    "type" => "FlexibleParameter",
    "name" => c.name,
    "starting_value" => _serialized_value(c; pars),
    "fixed" => c.fixed,
)

serialize(c::AdvancedParameter; pars=NamedTuple()) = LittleDict(
    "type" => "AdvancedParameter",
    "name" => c.name,
    "starting_value" => _serialized_value(c; pars),
    "boundaries" => c.boundaries,
    "uncertainty" => c.uncertainty,
    "fixed" => c.fixed,
)

function serialize(p::AbstractParameter; pars=NamedTuple())
    d = LittleDict{String,Any}("type" => _type_name(typeof(p)))
    for field in fieldnames(typeof(p))
        d[string(field)] = getfield(p, field)
    end
    return d
end

function serialize(c::AbstractConstructor; pars=NamedTuple())
    T = typeof(c)
    d = LittleDict{String,Any}("type" => _type_name(T))
    for field in fieldnames(T)
        d[string(field)] = _serialize_value(getfield(c, field); pars)
    end
    return d
end

function _serialize_value(x; pars=NamedTuple())
    x isa AbstractParameter && return serialize(x; pars)
    x isa AbstractConstructor && return serialize(x; pars)
    return x
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

"""
    deserialize(::Type{T}, all_fields) -> constructor_or_parameter, starting_parameters

Rebuild a parameter descriptor or constructor from serialized fields.

The second return value is a `NamedTuple` of starting values collected while
deserializing running parameters. Custom serializable types should implement
[`serialize`](@ref) / [`deserialize`](@ref) and call [`register!`](@ref) so type
names can be resolved from serialized data.
"""
function deserialize(::Type{<:Fixed}, all_fields)
    Fixed(all_fields["value"]), NamedTuple()
end

function deserialize(::Type{<:Running}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    Running(name), NamedTuple{(Symbol(name),)}((starting_value,))
end

function deserialize(::Type{<:FlexibleParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    fixed = get(all_fields, "fixed", false)
    FlexibleParameter(name, starting_value, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end

function deserialize(::Type{<:AdvancedParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    boundaries = Tuple(all_fields["boundaries"])
    uncertainty = all_fields["uncertainty"]
    fixed = get(all_fields, "fixed", false)
    AdvancedParameter(name, starting_value, boundaries, uncertainty, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end

function deserialize(::Type{T}, all_fields) where {T <: AbstractParameter}
    args = Any[all_fields[string(field)] for field in fieldnames(T)]
    T(args...), NamedTuple()
end

function deserialize(::Type{T}, all_fields) where {T <: AbstractConstructor}
    appendix = NamedTuple()
    args = Any[]
    for field in fieldnames(T)
        key = string(field)
        haskey(all_fields, key) ||
            error("Missing field $(repr(key)) when deserializing $(T)")
        value, part = _deserialize_value(all_fields[key], fieldtype(T, field))
        push!(args, value)
        appendix = merge(appendix, part)
    end
    T(args...), appendix
end

function _is_typed_dict(x)
    return x isa AbstractDict && haskey(x, "type")
end

function _deserialize_value(val, field_T)
    if _is_typed_dict(val)
        nested_T = _type_from_string(string(val["type"]))
        return deserialize(nested_T, val)
    end
    return _deserialize_plain(val, field_T), NamedTuple()
end

_deserialize_plain(val, ::Type{Float64}) = Float64(val)
_deserialize_plain(val, ::Type{Int}) = Int(val)
_deserialize_plain(val, ::Type{Bool}) = Bool(val)
_deserialize_plain(val, ::Type{String}) = String(val)
_deserialize_plain(val, ::Type{Tuple{Float64,Float64}}) =
    (Float64(val[1]), Float64(val[2]))
_deserialize_plain(val, ::Type{NTuple{N,T}}) where {N,T} =
    ntuple(i -> _deserialize_plain(val[i], T), N)
_deserialize_plain(val, field_T) = val
