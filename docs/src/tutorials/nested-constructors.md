# Nested Constructors

Nested constructors are the main reason to keep parameter metadata outside the
model object. A parent constructor can store child constructors, and
`running_values`, `fix!`, `release!`, `update!`, and `build_model` recurse through
the full tree.

This example builds a weighted mixture of two normal distributions. The final
object is a regular `MixtureModel` from `Distributions.jl`; the constructor tree
only describes how to assemble it.

```julia
using BuildConstructors
using Distributions

@with_parameters(Gauss; μ::P, σ::P, begin
    Normal(μ, σ)
end)

@with_parameters(Mixture; left, right, f_left::P, begin
    MixtureModel(
        [build_model(left, pars), build_model(right, pars)],
        [f_left, 1 - f_left],
    )
end)
```

The plain fields `left` and `right` are child constructors. The `f_left::P` field
is a parameter descriptor, so its resolved value is available as `f_left` inside
the body.

```julia
constructor = ConstructorOfMixture(
    ConstructorOfGauss(
        AdvancedParameter("μ_left", -1.0; boundaries = (-5.0, 5.0), uncertainty = 0.1),
        AdvancedParameter("σ_left", 0.8; boundaries = (0.05, 5.0), uncertainty = 0.05),
    ),
    ConstructorOfGauss(
        AdvancedParameter("μ_right", 1.2; boundaries = (-5.0, 5.0), uncertainty = 0.1),
        AdvancedParameter("σ_right", 0.5; boundaries = (0.05, 5.0), uncertainty = 0.05),
    ),
    AdvancedParameter("f_left", 0.6; boundaries = (0.0, 1.0), uncertainty = 0.02),
)
```

The metadata collectors see every parameter in the nested tree:

```julia
running_values(constructor)
# (μ_left = -1.0, σ_left = 0.8, μ_right = 1.2, σ_right = 0.5, f_left = 0.6)

running_lower_boundaries(constructor)
# (μ_left = -5.0, σ_left = 0.05, μ_right = -5.0, σ_right = 0.05, f_left = 0.0)
```

Use the collected values directly to build the model:

```julia
pars = running_values(constructor)
model = build_model(constructor, pars)
pdf(model, 0.0)
```

Mutating helpers also recurse through the tree:

```julia
fix!(constructor, (:σ_left, :σ_right))
running_values(constructor)

update!(constructor, (μ_left = -0.8, μ_right = 1.0, f_left = 0.55))
running_values(constructor)

release!(constructor, (:σ_left, :σ_right))
```

The pattern scales to deeper trees. A parent constructor does not need to know the
concrete type of each child; it only needs to call `build_model(child, pars)` at
the point where the final domain object is assembled.
