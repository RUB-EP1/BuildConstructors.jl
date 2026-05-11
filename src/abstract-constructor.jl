"""
    AbstractConstructor

Abstract supertype for objects that describe how to build another Julia object.

Subtypes usually store parameter descriptors and any non-parameter configuration
needed by `build_model`. Generic metadata utilities such as `running_values`,
`fix!`, `release!`, and `update!` recurse through fields of
`AbstractConstructor`s, so nested constructors compose naturally.
"""
abstract type AbstractConstructor end

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
for func in (
    :running_values,
    :running_uncertainties,
    :running_upper_boundaries,
    :running_lower_boundaries,
)
    @eval function $func(c::AbstractConstructor)
        _list = NamedTuple()
        for field in fieldnames(typeof(c))
            _list = merge(_list, $func(getfield(c, field)))
        end
        return _list
    end
end
