"""
    AbstractParameter

Abstract supertype for parameter descriptors.

A parameter descriptor is metadata about a numeric value, not necessarily the
numeric value itself. Subtypes should implement `BuildConstructors.value(p; pars)`
to define how the number is obtained when a constructor is built. They may also
implement `fix!`, `release!`, `update!`, `parameter_*` collectors, and name
collectors when they carry fixed/free state, defaults, bounds, or uncertainties.
"""
abstract type AbstractParameter end

# Any parameter realization, needs to implement the following functions:
# by default, these functions do nothing

"""
    fix!(constructor, par_names)

Fix specific parameters so they remain constant during fitting.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object
- `par_names`: A tuple, array, or iterable of parameter names as symbols (e.g., `(:m, :Γ)` or `[:m, :Γ]`)

# Examples
```julia
fix!(constructor, (:m, :Γ))  # Fix parameters m and Γ
fix!(constructor, [:c1])     # Fix parameter c1 using an array
```
"""
fix!(p::AbstractParameter, par_names) = nothing

"""
    release!(constructor, par_names)

Release specific parameters so they can vary during fitting.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object
- `par_names`: A tuple, array, or iterable of parameter names as symbols (e.g., `(:m, :Γ)` or `[:m, :Γ]`)

# Examples
```julia
release!(constructor, (:m, :Γ))  # Release parameters m and Γ
release!(constructor, [:c1])      # Release parameter c1 using an array
```
"""
release!(p::AbstractParameter, par_names) = nothing

"""
    update!(constructor, pars)

Update the current values of parameters in the constructor.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object
- `pars`: A `NamedTuple` or `ComponentArray` containing parameter names and their new values

# Examples
```julia
update!(constructor.model_p, (m = 1.9, Γ = 0.1))
update!(constructor.model_p, ComponentArray(m = 1.9, Γ = 0.1))
```
"""
update!(p::AbstractParameter, pars) = nothing

"""
    parameter_metadata(constructor)

Collect all named parameter descriptors as metadata entries.

Each entry is a `NamedTuple` with fields:
`name`, `value`, `uncertainty`, `lower`, `upper`, `fixed`, `parameter`, and
`parameter_type`. Duplicate names are preserved here so callers can inspect the
raw constructor tree; projection helpers deduplicate by name.
"""
parameter_metadata(p::AbstractParameter) = ()

_parameter_metadata_entry(parameter; name, value, uncertainty = missing, lower = -Inf, upper = Inf, fixed = false) = (
    (
        name = Symbol(name),
        value = value,
        uncertainty = uncertainty,
        lower = lower,
        upper = upper,
        fixed = fixed,
        parameter = parameter,
        parameter_type = typeof(parameter),
    ),
)

const _PARAMETER_METADATA_KEYS = (
    :name,
    :value,
    :uncertainty,
    :lower,
    :upper,
    :fixed,
    :parameter,
    :parameter_type,
)

_is_parameter_metadata_entry(entry) =
    entry isa NamedTuple && all(key -> key in keys(entry), _PARAMETER_METADATA_KEYS)

_is_parameter_metadata(metadata::Tuple) = all(_is_parameter_metadata_entry, metadata)

function _metadata_entries(p)
    metadata = p isa Tuple && _is_parameter_metadata(p) ? p : parameter_metadata(p)
    return _is_parameter_metadata(metadata) ? metadata : ()
end

function _metadata_names(metadata, state::Symbol)
    names = Symbol[]
    for entry in _metadata_entries(metadata)
        include_entry =
            state === :all ||
            (state === :running && !entry.fixed) ||
            (state === :fixed && entry.fixed)
        include_entry || continue
        entry.name in names || push!(names, entry.name)
    end
    return Tuple(names)
end

function _metadata_namedtuple(metadata, field::Symbol, state::Symbol)
    entries = _metadata_entries(metadata)
    return foldl(entries; init = NamedTuple()) do acc, entry
        include_entry =
            state === :all ||
            (state === :running && !entry.fixed) ||
            (state === :fixed && entry.fixed)
        if include_entry
            return merge(acc, NamedTuple{(entry.name,)}((getproperty(entry, field),)))
        end
        return acc
    end
end

"""
    parameter_values(constructor)

Get the stored values of all named parameters as a `NamedTuple`.
"""
parameter_values(p) = _metadata_namedtuple(p, :value, :all)

"""
    parameter_names(constructor)

Get the names of all named parameters as a tuple of symbols.
"""
parameter_names(p) = _metadata_names(p, :all)

"""
    running_names(constructor)

Get the names of all currently running parameters as a tuple of symbols.
"""
running_names(p) = _metadata_names(p, :running)

"""
    fixed_names(constructor)

Get the names of all currently fixed named parameters as a tuple of symbols.
"""
fixed_names(p) = _metadata_names(p, :fixed)

"""
    parameter_uncertainties(constructor)

Get the uncertainties for all named parameters as a `NamedTuple`.
"""
parameter_uncertainties(p) = _metadata_namedtuple(p, :uncertainty, :all)

"""
    parameter_upper_boundaries(constructor)

Get the upper boundaries for all named parameters as a `NamedTuple`.
"""
parameter_upper_boundaries(p) = _metadata_namedtuple(p, :upper, :all)

"""
    parameter_lower_boundaries(constructor)

Get the lower boundaries for all named parameters as a `NamedTuple`.
"""
parameter_lower_boundaries(p) = _metadata_namedtuple(p, :lower, :all)


# when applying the methods to any fields it fields, it does nothing 
fix!(p, par_names) = nothing
release!(p, par_names) = nothing
update!(p, pars) = nothing
parameter_metadata(p) = ()
"""
    running_values(constructor)

Get values for the currently running parameters.
"""
running_values(p) = _metadata_namedtuple(p, :value, :running)

"""
    running_uncertainties(constructor)

Get uncertainties for the currently running parameters.
"""
running_uncertainties(p) = _metadata_namedtuple(p, :uncertainty, :running)

"""
    running_upper_boundaries(constructor)

Get upper boundaries for the currently running parameters.
"""
running_upper_boundaries(p) = _metadata_namedtuple(p, :upper, :running)

"""
    running_lower_boundaries(constructor)

Get lower boundaries for the currently running parameters.
"""
running_lower_boundaries(p) = _metadata_namedtuple(p, :lower, :running)

"""
    fixed_values(constructor)

Get values for the currently fixed named parameters.
"""
fixed_values(p) = _metadata_namedtuple(p, :value, :fixed)

"""
    fixed_uncertainties(constructor)

Get uncertainties for the currently fixed named parameters.
"""
fixed_uncertainties(p) = _metadata_namedtuple(p, :uncertainty, :fixed)

"""
    fixed_upper_boundaries(constructor)

Get upper boundaries for the currently fixed named parameters.
"""
fixed_upper_boundaries(p) = _metadata_namedtuple(p, :upper, :fixed)

"""
    fixed_lower_boundaries(constructor)

Get lower boundaries for the currently fixed named parameters.
"""
fixed_lower_boundaries(p) = _metadata_namedtuple(p, :lower, :fixed)


"""
    fix!(constructor)

Fix all parameters in the constructor so they remain constant during fitting.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`)

# Examples
```julia
fix!(constructor)  # Fix all parameters
```
"""
fix!(c) = fix!(c, keys(parameter_values(c)))

"""
    release!(constructor)

Release all parameters in the constructor so they can vary during fitting.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`)

# Examples
```julia
release!(constructor)  # Release all parameters
```
"""
release!(c) = release!(c, keys(parameter_values(c)))
