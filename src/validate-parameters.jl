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
        hasfield(typeof(parameter), :name) || return
        name = Symbol(getfield(parameter, :name))

        if !haskey(first_occurrence, name)
            first_occurrence[name] = (parameter, path)
            return
        end

        previous, previous_path = first_occurrence[name]
        if previous != parameter
            throw(
                ArgumentError(
                    "parameter $(repr(name)) differs between " *
                    "$(join(string.(previous_path), ".")) and $(join(string.(path), "."))",
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
                "parameter $(repr(string(name))) at $(join([join(string.(path), ".") for path in paths], ", "))" for
                (name, paths) in shared_paths
            ),
            "; ",
        )
        @warn "Shared parameters detected: $shared"
    end

    return c
end
