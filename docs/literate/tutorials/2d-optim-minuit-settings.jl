# # 2D Optim With Minuit-Like Settings
#
# The fair Optim comparison is not plain `Fminbox(LBFGS())` versus Minuit.
# Minuit receives bounds, parameter scales, and an EDM stopping criterion. Optim
# needs comparable information before we judge the algorithmic difference.
#
# The tuned Optim rows therefore use:
#
# - `Fminbox` for bounds;
# - descriptor uncertainty as a metric scale;
# - Optim/NLSolversBase central finite differences by default;
# - an EDM-like stopping callback.
#
# Full-memory BFGS can receive a dense initial inverse Hessian. In this
# benchmark it is diagonal, with entries `step^2`.

using Optim

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "minimizer_survey.jl"))
using .TwoDimensionalFitExample
using .Fit2DMinimizerSurvey

loaded = load_fit_data()
stage = StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "Release only yields.")

bfgs_like_minuit = MethodSpec(
    "Optim.Fminbox(BFGS(); Minuit metric)",
    () -> (tolerance = 0.01, errordef = 0.5),
    true,
    :optim_minuit_bfgs,
    "BFGS with descriptor-scale initial inverse Hessian and EDM callback.",
)

results = run_survey(
    loaded.data2d[1:250];
    stages = [stage],
    methods = [bfgs_like_minuit],
    maxiters = 25,
    max_objective_calls = 500,
    max_seconds = 20.0,
)

# LBFGS does not store the same full inverse Hessian object as BFGS. The tuned
# LBFGS row therefore injects descriptor scale through the `Fminbox`
# preconditioner path and uses a diagonal EDM proxy.

lbfgs_like_minuit = MethodSpec(
    "Optim.Fminbox(LBFGS(); Minuit metric)",
    () -> (method = LBFGS(m = 10, scaleinvH0 = false), tolerance = 0.01, errordef = 0.5),
    true,
    :optim_minuit_lbfgs,
    "LBFGS with descriptor-scaled box preconditioner and EDM proxy.",
)

# The useful lesson is that Optim can reach the same minimum efficiently once
# it receives the same kind of scale information. The algorithm is not magic;
# the setup matters.
