abstract type AbstractConstructor end

build_model(c::AbstractConstructor, pars) =
    error("`build_model` not implemented for $(typeof(c)). You need to define a `build_mode(c::ConstructorOfYourModel, pars) -> YourModel` function for your constructor.")

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
