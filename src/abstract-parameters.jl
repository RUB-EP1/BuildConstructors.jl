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
    parameter_names(constructor)

Get the names of all named parameters as a tuple of symbols.

The returned tuple can be used to filter `parameter_values`,
`parameter_uncertainties`, `parameter_upper_boundaries`, or
`parameter_lower_boundaries`.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A tuple of parameter names as symbols.

# Examples
```julia
parameter_names(constructor)
# Returns (:m, :Γ, :σ, :c1, :fs)
```
"""
parameter_names(p::AbstractParameter) = ()

"""
    running_names(constructor)

Get the names of all currently running parameters as a tuple of symbols.

This is the free-parameter counterpart to `fixed_names`: fixed
`FlexibleParameter` and `AdvancedParameter` descriptors are omitted, while plain
`Running` parameters are always included.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A tuple of running parameter names as symbols.

# Examples
```julia
fix!(constructor, (:m,))
running_names(constructor)
# Returns all parameter names except m
```
"""
running_names(p::AbstractParameter) = ()

"""
    fixed_names(constructor)

Get the names of all currently fixed named parameters as a tuple of symbols.

`Fixed` descriptors are omitted because they do not carry names.

# Arguments
- `constructor`: A constructor object (e.g., `ConstructorOfPRBModel`) or a parameter object

# Returns
A tuple of fixed parameter names as symbols.

# Examples
```julia
fix!(constructor, (:m,))
fixed_names(constructor)
# Returns (:m,) when m is a fixed FlexibleParameter or AdvancedParameter
```
"""
fixed_names(p::AbstractParameter) = ()

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
parameter_names(p) = ()
running_names(p) = ()
fixed_names(p) = ()
parameter_uncertainties(p) = NamedTuple()
parameter_upper_boundaries(p) = NamedTuple()
parameter_lower_boundaries(p) = NamedTuple()


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
