# # 2D Optim Derivatives
#
# Derivative handling is one of the central findings of this branch.
#
# `AdvancedParameter.uncertainty` is a parameter scale for Minuit errors and
# Optim metrics. It is not a finite-difference perturbation. Reusing it as the
# finite-difference epsilon made the number of NLL calls explode. Optim's
# internal finite differences give a much fairer baseline.

using ADTypes
using LinearAlgebra
using Optim
import ReverseDiff

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
using .TwoDimensionalFitExample

descriptor_inverse_hessian(problem) = Diagonal(abs2.(collect(problem.step)))

function run_bfgs_with_backend(problem; autodiff = nothing, maxiters = 25, max_calls = 500)
    method = Fminbox(BFGS(initial_invH = _ -> descriptor_inverse_hessian(problem)))
    options = Optim.Options(
        iterations = maxiters,
        outer_iterations = maxiters,
        f_calls_limit = max_calls,
        x_abstol = 0.0,
        x_reltol = 0.0,
        f_abstol = 0.0,
        f_reltol = 0.0,
        g_abstol = 0.0,
    )

    if autodiff === nothing
        return optimize(problem.objective, problem.lower, problem.upper, problem.start, method, options)
    end
    return optimize(problem.objective, problem.lower, problem.upper, problem.start, method, options; autodiff)
end

loaded = load_fit_data()
constructor = build_2d_constructor(length(loaded.data2d))
fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, loaded.data2d[1:250])

# With no `autodiff` keyword, Optim/NLSolversBase computes numerical gradients
# using its internal finite-difference rules.

finite_diff_result = run_bfgs_with_backend(problem)

# ReverseDiff is appropriate for one scalar NLL and many parameters. It reduces
# counted objective calls because gradient evaluation no longer loops over
# finite-difference probes. Importing `ReverseDiff` activates the needed
# DifferentiationInterface extension.

reverse_diff_result = run_bfgs_with_backend(problem; autodiff = AutoReverseDiff())

# ReverseDiff also exposed an upstream compatibility issue:
# `DistributionsHEP.CrystalBall` requires all constructor arguments to have the
# same concrete numeric type, while a staged fit may trace only released
# parameters. The local compatibility file promotes mixed tracked/Float64
# arguments before constructing the CrystalBall distribution.
