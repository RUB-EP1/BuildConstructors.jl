# 2D Fit Benchmark Framework

The 2D fit example is a research benchmark for minimizer behavior, not a
single script whose only goal is to find one set of parameters. It keeps the
data, constructor tree, objective, computation budget, and score table stable
while minimizer families and configurations are varied.

The example lives under `examples/2d_distribution_fit` and is intentionally
split by concern:

- `src/two_dimensional_fit.jl` defines the data loader, model constructors,
  and extended negative log-likelihood.
- `src/survey_core.jl` defines stages, budgets, result rows, and Markdown/CSV
  scoreboards.
- `src/method_specs.jl` lists named minimizer configurations.
- Runner files such as `src/optim_runners.jl` and `src/minuit2_runner.jl`
  keep framework-specific setup readable.

The model is a two-dimensional extended mixture in `mKK1` and `mKK2`:

- `phi phi`: signal shape in both axes,
- `mixed`: signal in one axis and background in the other,
- `kkkk`: background in both axes.

The key BuildConstructors idea is that the fitted domain object remains a
normal Julia model, while parameter metadata lives in descriptors.

````julia
using BuildConstructors
using ComponentArrays

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
using .TwoDimensionalFitExample

loaded = load_fit_data()
constructor = build_2d_constructor(length(loaded.data2d))

start = ComponentArray(running_values(constructor))
lower = ComponentArray(running_lower_boundaries(constructor))
upper = ComponentArray(running_upper_boundaries(constructor))
step = ComponentArray(running_uncertainties(constructor))
````

The fit problem packages the constructor state into a compact optimizer-facing
object. The `objective` receives a `ComponentArray` containing only the
currently released parameters.

````julia
fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, loaded.data2d)

problem.names
problem.start
problem.lower
problem.upper
problem.step
````

The benchmark runner records the information needed to compare methods:
convergence status, best NLL, objective calls, elapsed time, EDM-like
diagnostics where available, and any budget or error outcome.

Run a small survey from the repository root:

```bash
FIT2D_SAMPLE_SIZE=250 FIT2D_MAXITERS=25 FIT2D_MAX_CALLS=500 FIT2D_MAX_SECONDS=20 \
  julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/04_minimizer_survey.jl
```

The generated files are:

- `examples/2d_distribution_fit/results/minimizer_survey.csv`
- `examples/2d_distribution_fit/results/minimizer_survey.md`

The CSV appends by default so new minimizer cases can be added without losing
earlier evidence. Set `FIT2D_APPEND=false` when a clean run is desired.

