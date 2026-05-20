# 2D Optim With Minuit-Like Settings

A fair Optim comparison gives Optim the same kind of information that Minuit
receives: bounds, a parameter scale, and an EDM-like stopping criterion.

This notebook implements the tuned BFGS/LBFGS pieces inline. The reusable
harness keeps these helpers in separate runner files, but the logic is small
enough to study directly.

````julia
using LinearAlgebra
using Optim

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
using .TwoDimensionalFitExample
````

The descriptor uncertainty is the local metric scale. It is not a
finite-difference epsilon. For BFGS, use it as an initial inverse Hessian:

````julia
descriptor_inverse_hessian(problem) = Diagonal(abs2.(collect(problem.step)))
````

For LBFGS inside `Fminbox`, the box solver already prepares a barrier
preconditioner. A Minuit-like metric can be injected by adding the descriptor
Hessian scale to that barrier scale.

````julia
function descriptor_box_precondprep(problem)
    descriptor_hessian = Diagonal(1 ./ abs2.(collect(problem.step)))
    return (P, x) -> P + descriptor_hessian
end
````

Minuit stops using an EDM target. For an NLL, `errordef = 0.5`. The tuned rows
use the same tolerance and an EDM-style callback.

````julia
minuit_edm_goal(; tolerance = 0.01, errordef = 0.5) =
    max(2e-3 * tolerance * errordef, 4 * sqrt(eps()))

function bfgs_edm_callback(last_edm, goal)
    return state -> begin
        metadata = state.metadata
        haskey(metadata, "g(x)") || return false
        haskey(metadata, "~inv(H)") || return false
        g = metadata["g(x)"]
        invH = metadata["~inv(H)"]
        last_edm[] = dot(g, invH * g) / 2
        return last_edm[] < goal
    end
end

function minuit_like_options(maxiters, max_calls, max_seconds, callback)
    return Optim.Options(
        iterations = maxiters,
        outer_iterations = maxiters,
        f_calls_limit = max_calls,
        time_limit = max_seconds,
        x_abstol = 0.0,
        x_reltol = 0.0,
        f_abstol = 0.0,
        f_reltol = 0.0,
        g_abstol = 0.0,
        outer_x_abstol = 0.0,
        outer_x_reltol = 0.0,
        outer_f_abstol = 0.0,
        outer_f_reltol = 0.0,
        outer_g_abstol = 0.0,
        callback = callback,
    )
end
````

The tuned BFGS row is now explicit: bounded optimization, Optim internal
finite differences, descriptor-scale initial inverse Hessian, and EDM
stopping.

````julia
function run_tuned_bfgs(problem; maxiters = 25, max_calls = 500, max_seconds = 20.0)
    edm_goal = minuit_edm_goal()
    last_edm = Ref(Inf)
    method = Fminbox(BFGS(initial_invH = _ -> descriptor_inverse_hessian(problem)))
    options = minuit_like_options(maxiters, max_calls, max_seconds, bfgs_edm_callback(last_edm, edm_goal))
    result = optimize(problem.objective, problem.lower, problem.upper, problem.start, method, options)
    return (; result, edm = last_edm[], converged = Optim.converged(result) || last_edm[] < edm_goal)
end
````

LBFGS is similar, but it does not expose a full inverse Hessian in the same
way. The benchmark uses a descriptor-scaled preconditioner and a diagonal EDM
proxy in the reusable harness.

````julia
function run_tuned_lbfgs(problem; maxiters = 25, max_calls = 500, max_seconds = 20.0)
    method = Fminbox(LBFGS(m = 10, scaleinvH0 = false); precondprep = descriptor_box_precondprep(problem))
    options = Optim.Options(iterations = maxiters, outer_iterations = maxiters, f_calls_limit = max_calls, time_limit = max_seconds)
    result = optimize(problem.objective, problem.lower, problem.upper, problem.start, method, options)
    return (; result, converged = Optim.converged(result))
end

loaded = load_fit_data()
constructor = build_2d_constructor(length(loaded.data2d))
fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, loaded.data2d[1:250])

bfgs_result = run_tuned_bfgs(problem)
lbfgs_result = run_tuned_lbfgs(problem)
````

The lesson is not that Optim must imitate Minuit exactly. The lesson is that
Optim reaches the same basin once the comparison includes the information
Minuit was already given: bounds, scales, and a meaningful stopping target.

