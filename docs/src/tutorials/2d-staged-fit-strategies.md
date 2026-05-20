# 2D Staged Fit Strategies

`fix!` and `release!` are not just convenience helpers. They define the
fitting strategy.

Releasing all parameters from the start is a useful stress test, but staged
release can be faster and more stable because each optimizer sees a smaller,
better-scaled local problem. The benchmark currently studies:

- `yield_only`: release the three extended yields;
- `mass_only`: release `mu_B`;
- `shape_only`: release `sigma_B`, `alpha_B`, and `k_bkg_kk`;
- `all_free`: release every fit parameter.

These stages are encoded as data, so the same stages can be run across Minuit,
tuned Optim, ReverseDiff, and derivative-free baselines.

````julia
using BuildConstructors

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "minimizer_survey.jl"))
using .TwoDimensionalFitExample
using .Fit2DMinimizerSurvey

default_stage_specs()
````

A manual staged fit updates the constructor after each stage. This is the
small-scale pattern:

````julia
loaded = load_fit_data()
constructor = build_2d_constructor(length(loaded.data2d))

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
yield_problem = fitting_problem(constructor, loaded.data2d)
````

After fitting the yields:

```julia
update!(constructor, fitted_yields)
```

Then release the next block:

````julia
fix!(constructor)
release!(constructor, (:mu_B,))
mass_problem = fitting_problem(constructor, loaded.data2d)
````

The survey harness currently runs each stage from the same constructor start
unless a `warm_start` is supplied. That separation is useful: it lets us
compare independent stage difficulty and then add explicit warm-start studies
without hiding where the performance gain came from.

Future strategy rows should make the sequence visible in their name, for
example `yield -> mass -> shape -> all_free`, and should record both total
calls and final all-free NLL.

