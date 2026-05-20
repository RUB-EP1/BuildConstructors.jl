# 2D Staged Fit Strategies

`fix!` and `release!` define the fitting strategy. Releasing all parameters
from the start is a useful stress test, but staged release gives smaller,
better-scaled local problems and makes failures easier to diagnose.

````julia
using BuildConstructors
using Optim

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
using .TwoDimensionalFitExample

struct StageSpec
    name::String
    release::Tuple{Vararg{Symbol}}
    notes::String
end

stages = StageSpec[
    StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "Stabilize the extended yields."),
    StageSpec("mass_only", (:mu_B,), "Move the signal peak location."),
    StageSpec("shape_only", (:sigma_B, :alpha_B, :k_bkg_kk), "Study width, tail, and background slope."),
    StageSpec("all_free", (:y_phiphi, :y_mixed, :y_kkkk, :mu_B, :sigma_B, :alpha_B, :k_bkg_kk), "Final stress test."),
]
````

The core operation is tiny: fix everything, release one stage, construct the
optimizer-facing problem, fit it, and write the result back into the
constructor before the next stage.

````julia
function run_stage!(constructor, data, stage; maxiters = 25)
    fix!(constructor)
    release!(constructor, stage.release)
    problem = fitting_problem(constructor, data)
    result = optimize(
        problem.objective,
        problem.lower,
        problem.upper,
        problem.start,
        Fminbox(LBFGS()),
        Optim.Options(iterations = maxiters),
    )
    update!(constructor, Optim.minimizer(result))
    return (; stage = stage.name, result, best_pars = Optim.minimizer(result))
end

loaded = load_fit_data()
data = loaded.data2d[1:250]
constructor = build_2d_constructor(length(data))

stage_results = [
    run_stage!(constructor, data, stage)
    for stage in stages
]
````

The survey harness uses the same idea in two modes:

- independent stage rows, useful for measuring how hard each subproblem is;
- warm-start strategy rows, useful for measuring total calls and final NLL of
  sequences such as `yield -> mass -> shape -> all_free`.

Keeping those modes separate prevents a staged strategy from hiding where the
performance gain came from.

