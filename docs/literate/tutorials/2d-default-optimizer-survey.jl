# # 2D Default Optimizer Survey
#
# The survey includes deliberately plain minimizer rows. These are not expected
# to win; they answer a different question: what happens if users try the
# obvious default settings?
#
# The current default-style rows include:
#
# - `Optim.Fminbox(LBFGS())`;
# - `Optim.Fminbox(BFGS())`;
# - `Optim.NelderMead()`;
# - `Optim.ParticleSwarm()`.
#
# For this constrained extended NLL, the derivative-free defaults are mainly
# negative controls. They can get stuck, probe invalid regions, or fail to reach
# the best NLL within budget. That is useful evidence for documentation.

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "minimizer_survey.jl"))
using .TwoDimensionalFitExample
using .Fit2DMinimizerSurvey

methods = default_method_specs()
default_rows = filter(methods) do spec
    spec.name in (
        "Optim.Fminbox(LBFGS())",
        "Optim.Fminbox(BFGS())",
        "Optim.NelderMead()",
        "Optim.ParticleSwarm()",
    )
end

loaded = load_fit_data()
results = run_survey(
    loaded.data2d[1:250];
    stages = [StageSpec("all_free", (:y_phiphi, :y_mixed, :y_kkkk, :mu_B, :sigma_B, :alpha_B, :k_bkg_kk), "All-free stress test.")],
    methods = default_rows,
    maxiters = 25,
    max_objective_calls = 500,
    max_seconds = 20.0,
)

# The compact Markdown table is intentionally focused:
#
# - status,
# - best NLL,
# - ΔNLL to the best row,
# - objective calls,
# - elapsed seconds,
# - EDM where available.
#
# Add new candidate methods in `src/method_specs.jl`, not inside the reporting
# code. That keeps the scoreboard stable and makes the comparison extensible.
