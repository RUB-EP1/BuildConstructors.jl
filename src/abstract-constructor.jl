"""
    AbstractConstructor

Abstract supertype for objects that describe how to build another Julia object.

Subtypes usually store parameter descriptors and any non-parameter configuration
needed by `build_model`. Generic metadata utilities such as `parameter_metadata`,
`parameter_values`, `parameter_names`, `running_names`, `fixed_names`, `fix!`,
`release!`, and `update!` recurse through fields of `AbstractConstructor`s, so
nested constructors compose naturally.
"""
abstract type AbstractConstructor end

function _parameter_name(p::AbstractParameter)
    hasfield(typeof(p), :name) || return nothing
    return Symbol(getfield(p, :name))
end

function _visit_parameters(f, p::AbstractParameter, path)
    f(p, path)
    return nothing
end

function _visit_parameters(f, c::AbstractConstructor, path = ())
    for field in fieldnames(typeof(c))
        _visit_parameters(f, getfield(c, field), (path..., field))
    end
    return nothing
end

_visit_parameters(f, value, path) = nothing

function _parameter_differences(left::AbstractParameter, right::AbstractParameter)
    left == right && return ()
    typeof(left) === typeof(right) || return (:parameter_type,)
    return Tuple(
        field for field in fieldnames(typeof(left)) if
        !isequal(getfield(left, field), getfield(right, field))
    )
end

_parameter_path(path) = join(string.(path), ".")

"""
    validate_parameters(constructor)

Validate named parameters in a constructor tree and return `constructor`.

Repeated names represent shared parameters. A single warning summarizes all
shared parameters whose descriptors compare equal with `==`. An `ArgumentError`
is thrown when descriptors with the same name differ in concrete type or any
field value.

Manual `AbstractConstructor` implementations can enforce validation during
construction by calling this function after `new`:

```julia
function MyConstructor(left, right)
    constructor = new(left, right)
    return validate_parameters(constructor)
end
```
"""
function validate_parameters(c::AbstractConstructor)
    first_occurrence = Dict{Symbol,Tuple{AbstractParameter,Tuple}}()
    shared_paths = Dict{Symbol,Vector{Tuple}}()

    _visit_parameters(c) do parameter, path
        name = _parameter_name(parameter)
        isnothing(name) && return

        if !haskey(first_occurrence, name)
            first_occurrence[name] = (parameter, path)
            return
        end

        previous, previous_path = first_occurrence[name]
        differences = _parameter_differences(previous, parameter)
        if !isempty(differences)
            difference_list = join(string.(differences), ", ")
            throw(
                ArgumentError(
                    "parameter $(repr(name)) differs between " *
                    "$(_parameter_path(previous_path)) and $(_parameter_path(path)) " *
                    "in: $difference_list",
                ),
            )
        end

        paths = get!(shared_paths, name) do
            Tuple[previous_path]
        end
        push!(paths, path)
    end

    if !isempty(shared_paths)
        shared = join(
            (
                "$(repr(name)) at $(join(_parameter_path.(paths), ", "))" for
                (name, paths) in shared_paths
            ),
            "; ",
        )
        @warn "Shared parameters detected: $shared"
    end

    return c
end

"""
    build_model(constructor::AbstractConstructor, pars)

Build the domain object described by `constructor` using parameter values from
`pars`.

`BuildConstructors.jl` deliberately does not constrain either argument beyond this
convention: `pars` can be a `NamedTuple`, `ComponentArray`, or any object your
parameter descriptors understand, and the return value can be any Julia object.
Implement this method for each constructor type you define.
"""
build_model(c::AbstractConstructor, pars) =
    error("`build_model` not implemented for $(typeof(c)). You need to define a `build_model(c::ConstructorOfYourModel, pars) -> YourModel` function for your constructor.")

# for all constructors, apply the function to all fields
for func in (:fix!, :release!, :update!)
    @eval function $func(c::AbstractConstructor, pars)
        for field in fieldnames(typeof(c))
            $func(getfield(c, field), pars)
        end
    end
end

# collection functionality
function parameter_metadata(c::AbstractConstructor)
    return (
        Base.Iterators.flatten(
            parameter_metadata(getfield(c, field)) for field in fieldnames(typeof(c))
        )...,
    )
end
