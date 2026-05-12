# Type registry for extensible deserialization
const _type_registry = Dict{String,Type}()

"""
    register!(type::Type; type_name::String = string(type))

Register a custom type for deserialization. This allows users to define custom parameter types
or model constructors that can be properly deserialized from JSON.

# Example
```julia
struct MyParameter <: BuildConstructors.AbstractParameter
end

BuildConstructors.register!(MyParameter)  # Uses "MyParameter" as default name
# or
BuildConstructors.register!(MyParameter; type_name="CustomName")
```

After registration, types serialized with `"type" => "MyParameter"` can be deserialized.
"""
function register!(type::Type; type_name::String = string(type))
    _type_registry[type_name] = type
    return nothing
end

"""
    _type_from_string(type_name::String) -> Type

Resolve a serialized `"type"` field to a `Type`: registered names first,
then identifiers on the activated `physics_models_extension()` module
(if any), then `BuildConstructors`, then `Base`. Arbitrary Julia expressions are
never parsed or evaluated — only simple identifiers are allowed — so untrusted JSON
cannot cause code execution via this path.
"""
function _type_from_string(type_name::String)
    # First check registry for user-registered types
    if haskey(_type_registry, type_name)
        return _type_registry[type_name]
    end
    if !Base.isidentifier(type_name)
        error(
            "Unknown type $(repr(type_name)): not a valid identifier for deserialization. " *
            "Call `register!` for custom types.",
        )
    end
    sym = Symbol(type_name)
    ext = physics_models_extension()
    if ext !== nothing && isdefined(ext, sym)
        cand = getfield(ext, sym)
        if cand isa Union{DataType, UnionAll}
            return cand
        end
    end
    mod = BuildConstructors
    if isdefined(mod, sym)
        val = getfield(mod, sym)
        val isa Union{DataType, UnionAll} && return val
    end
    if isdefined(Base, sym)
        val = getfield(Base, sym)
        val isa Union{DataType, UnionAll} && return val
    end
    error(
        "Type '$type_name' not found in registry or active extensions. " *
        "Use `BuildConstructors.register!` for custom types.",
    )
end
