# parameter types
register!(Fixed)
register!(Running)
register!(FlexibleParameter)
register!(AdvancedParameter)

# Physics constructor registration and serialization ship in PhysicsModelsExt; see physics_io.jl.

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

"""
    serialize(constructor_or_parameter; pars)

Convert a parameter descriptor or constructor into a dictionary-like object.

For running parameters, `pars` supplies the current numerical values that should be
stored as starting values. Serialization is optional: the core constructor pattern
works without it, but these methods are useful when constructor descriptions need
to be saved to JSON or a database.
"""
serialize(c::Fixed; pars) = LittleDict("type" => "Fixed", "value" => c.value)
serialize(c::Running; pars) =
    LittleDict("type" => "Running", "name" => c.name, "starting_value" => value(c; pars))

"""
    deserialize(::Type{T}, all_fields) -> constructor_or_parameter, starting_parameters

Rebuild a parameter descriptor or constructor from serialized fields.

The second return value is a `NamedTuple` of starting values collected while
deserializing running parameters. Custom serializable types should implement this
method and call `register!(T)` so type names can be resolved from serialized data.
"""
function deserialize(::Type{<:Fixed}, all_fields)
    value = all_fields["value"]
    Fixed(value), NamedTuple()
end

function deserialize(::Type{<:Running}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    Running(name), NamedTuple{(Symbol(name),)}((starting_value,))
end

serialize(c::FlexibleParameter; pars) = LittleDict(
    "type" => "FlexibleParameter",
    "name" => c.name,
    "starting_value" => value(c; pars),
    "fixed" => c.fixed,
)

function deserialize(::Type{<:FlexibleParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    fixed = get(all_fields, "fixed", false)
    FlexibleParameter(name, starting_value, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end

serialize(c::AdvancedParameter; pars) = LittleDict(
    "type" => "AdvancedParameter",
    "name" => c.name,
    "starting_value" => value(c; pars),
    "boundaries" => c.boundaries,
    "uncertainty" => c.uncertainty,
    "fixed" => c.fixed,
)

function deserialize(::Type{<:AdvancedParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    boundaries = Tuple(all_fields["boundaries"])
    uncertainty = all_fields["uncertainty"]
    fixed = get(all_fields, "fixed", false)
    AdvancedParameter(name, starting_value, boundaries, uncertainty, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end
