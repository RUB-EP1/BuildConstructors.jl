"""
    AbstractParameter

Abstract supertype for parameter descriptors.

A parameter descriptor is metadata about a numeric value, not necessarily the
numeric value itself. Subtypes should implement `BuildConstructors.value(p; pars)`
to define how the number is obtained when a constructor is built. They may also
implement `fix!`, `release!`, `update!`, `parameter_*` collectors,
`released_values`, and `fixed_values` when they carry fixed/free state,
defaults, bounds, or uncertainties.
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
    parameter_values(constructor)

Get the stored values of all named parameters as a `NamedTuple`. The method is used to collect the starting values.

Returns a `NamedTuple` where each key is a parameter name.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of parameter names and their current values.
Parameter without a stored value return `missing`.

# Examples
```julia
vals = parameter_values(constructor)
# Returns: (m = 2.0, Γ = 0.2, σ = missing, c1 = 0.3, fs = 0.5)
```
"""
parameter_values(p::AbstractParameter) = NamedTuple()

"""
    released_values(constructor)

Get the stored values of all currently released parameters as a `NamedTuple`.

This is the free-parameter counterpart to `parameter_values`: fixed `FlexibleParameter`
and `AdvancedParameter` descriptors are omitted, while plain `Running` parameters
are always included.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of released parameter names and their current values. Parameters
without a stored value return `missing`.

# Examples
```julia
fix!(constructor, (:m,))
vals = released_values(constructor)
# Returns all parameter values except m
```
"""
released_values(p::AbstractParameter) = NamedTuple()

"""
    fixed_values(constructor)

Get the stored values of all currently fixed named parameters as a `NamedTuple`.

This is the fixed-parameter counterpart to `released_values`: fixed
`FlexibleParameter` and `AdvancedParameter` descriptors are included, while plain
`Running` parameters are omitted. `Fixed` descriptors are also omitted because
they do not carry names.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of fixed parameter names and their current stored values.

# Examples
```julia
fix!(constructor, (:m,))
vals = fixed_values(constructor)
# Returns (m = 2.0,) when m is a fixed FlexibleParameter or AdvancedParameter
```
"""
fixed_values(p::AbstractParameter) = NamedTuple()

"""
    parameter_uncertainties(constructor)

Get the uncertainties for all named parameters as a `NamedTuple`.

Returns a `NamedTuple` where each key is a parameter name and each value is the parameter's
uncertainty. Parameters without defined uncertainties return `missing`.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of parameter names and their uncertainties (or `missing` if not defined).

# Examples
```julia
unc = parameter_uncertainties(constructor)
# Returns: (m = missing, Γ = missing, σ = missing, c1 = missing, fs = 0.01)
```
"""
parameter_uncertainties(p::AbstractParameter) = NamedTuple()

"""
    parameter_upper_boundaries(constructor)

Get the upper boundaries for all named parameters as a `NamedTuple`.

Returns a `NamedTuple` where each key is a parameter name.
Parameters without a stored upper boundary return `Inf`.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of parameter names and their upper boundaries.

# Examples
```julia
upper = parameter_upper_boundaries(constructor)
# Returns: (m = Inf, Γ = Inf, σ = Inf, c1 = Inf, fs = 1.0)
```
"""
parameter_upper_boundaries(p::AbstractParameter) = NamedTuple()

"""
    parameter_lower_boundaries(constructor)

Get the lower boundaries for all named parameters as a `NamedTuple`.

Returns a `NamedTuple` where each key is a parameter name and each value is the parameter's
lower boundary. Parameters without explicit boundaries return `-Inf`.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A `NamedTuple` of parameter names and their lower boundaries.

# Examples
```julia
lower = parameter_lower_boundaries(constructor)
# Returns: (m = -Inf, Γ = -Inf, σ = -Inf, c1 = -Inf, fs = 0.0)
```
"""
parameter_lower_boundaries(p::AbstractParameter) = NamedTuple()


# when applying the methods to any fields it fields, it does nothing 
fix!(p, par_names) = nothing
release!(p, par_names) = nothing
update!(p, pars) = nothing
parameter_values(p) = NamedTuple()
released_values(p) = NamedTuple()
fixed_values(p) = NamedTuple()
parameter_uncertainties(p) = NamedTuple()
parameter_upper_boundaries(p) = NamedTuple()
parameter_lower_boundaries(p) = NamedTuple()

# Backward-compatible aliases for the old "running_*" collector names.
running_values(p) = parameter_values(p)
running_uncertainties(p) = parameter_uncertainties(p)
running_upper_boundaries(p) = parameter_upper_boundaries(p)
running_lower_boundaries(p) = parameter_lower_boundaries(p)


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
