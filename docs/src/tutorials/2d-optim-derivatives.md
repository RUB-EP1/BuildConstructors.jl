# 2D Optim Derivatives

This branch found an important derivative lesson. `AdvancedParameter`
uncertainty is a parameter scale for Minuit errors and Optim metrics. It is
not a finite-difference epsilon.

An early experiment reused the descriptor step as the finite-difference
perturbation. That made objective-call counts explode. The corrected benchmark
lets Optim/NLSolversBase choose its internal central finite-difference scale.
On the focused yield-only fit, that brought tuned Optim back to a modest call
count while keeping the same minimum.

````julia
using ADTypes
using Optim
import ReverseDiff

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "minimizer_survey.jl"))
using .TwoDimensionalFitExample
using .Fit2DMinimizerSurvey

loaded = load_fit_data()
stage = StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "Release only yields.")

finite_diff_bfgs = MethodSpec(
    "Optim.Fminbox(BFGS(); Minuit metric)",
    () -> (tolerance = 0.01, errordef = 0.5),
    true,
    :optim_minuit_bfgs,
    "Optim internal finite differences.",
)

reversediff_bfgs = MethodSpec(
    "Optim.Fminbox(BFGS(); Minuit metric, ReverseDiff)",
    () -> (tolerance = 0.01, errordef = 0.5, autodiff = AutoReverseDiff()),
    true,
    :optim_minuit_bfgs,
    "ReverseDiff gradients through Optim.",
)

results = run_survey(
    loaded.data2d[1:250];
    stages = [stage],
    methods = [finite_diff_bfgs, reversediff_bfgs],
    maxiters = 25,
    max_objective_calls = 500,
    max_seconds = 20.0,
)
````

ReverseDiff is useful for this NLL shape: one scalar objective and many
parameters. In the current scoreboard it preserves the minimum and sharply
reduces counted objective calls. Small samples can still be dominated by AD
tracing/preparation overhead, especially with LBFGS.

ReverseDiff also exposed a genuine upstream compatibility issue:
`DistributionsHEP.CrystalBall` requires all constructor arguments to share one
concrete numeric type, while ReverseDiff often traces only released
parameters. The local workaround is isolated in
`examples/2d_distribution_fit/src/distributionshep_compat.jl`, and the issue
is documented upstream in JuliaHEP/DistributionsHEP.jl#45.

