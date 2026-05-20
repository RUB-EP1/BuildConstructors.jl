# # 2D Minuit2 Study
#
# The current reference configuration is native `Minuit2.Migrad(strategy=1)`
# with explicit bounds and descriptor-derived parameter errors. The important
# detail is that this uses the low-level Minuit2 API through a small
# `ComponentArray` wrapper, not the generic `Optimization.jl` interface.
#
# The wrapper lives in:
#
# - `examples/2d_distribution_fit/src/Minuit2CAInterface.jl`
#
# It provides an Optim-like call shape:
#
# ```julia
# result = optimize(objective, initial, Minuit2CA(...))
# fitted = minimizer(result)
# minuit = original(result)
# ```
#
# `fitted` is a `ComponentArray`, and the original Minuit object remains
# available for diagnostics or follow-up calls such as `hesse!`.

using ComponentArrays

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "Minuit2CAInterface.jl"))

using .TwoDimensionalFitExample
using .Minuit2CAInterface

loaded = load_fit_data()
constructor = build_2d_constructor(length(loaded.data2d))

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, loaded.data2d)

result = Minuit2CAInterface.optimize(
    problem.objective,
    problem.start,
    Minuit2CA(;
        strategy = 1,
        tolerance = 0.01,
        errordef = 0.5,
        maxcalls = 500,
        errors = problem.step,
        lower = problem.lower,
        upper = problem.upper,
        names = problem.names,
    ),
)

fitted = Minuit2CAInterface.minimizer(result)
minuit = Minuit2CAInterface.original(result)

# The Minuit-specific settings mean:
#
# - `lower` / `upper` prevent invalid physical regions such as negative yields.
# - `errors = problem.step` passes Minuit's initial parameter errors / step
#   scales. These come from `AdvancedParameter.uncertainty`.
# - `errordef = 0.5` is appropriate for a negative log-likelihood.
# - `strategy = 1` is the good default for this benchmark: robust enough without
#   spending the extra calls of strategy 2.
#
# The `Optimization.jl` interface is still worth tracking, but this branch found
# two gaps for this benchmark:
#
# - the locally resolved Minuit2/Optimization extension had a compatibility
#   error in `solve`;
# - even after that is fixed, the extension does not expose per-parameter
#   Minuit errors/steps, fixed masks, retry controls, or post-fit `hesse!` /
#   `minos!` controls.
#
# That is why the benchmark keeps `Minuit2CAInterface.jl` as a compact, reusable
# local adapter.
