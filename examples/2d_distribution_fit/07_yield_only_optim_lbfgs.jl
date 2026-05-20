using Pkg

const SCRIPT_DIR = @__DIR__
Pkg.activate(SCRIPT_DIR)

include(joinpath(SCRIPT_DIR, "src", "two_dimensional_fit.jl"))
include(joinpath(SCRIPT_DIR, "src", "optim_support.jl"))

using ADTypes
using BuildConstructors
using LinearAlgebra
using Optim
using Printf
import ReverseDiff
using .TwoDimensionalFitExample

function env_int(name, default)
    return parse(Int, get(ENV, name, string(default)))
end

function env_float(name, default)
    return parse(Float64, get(ENV, name, string(default)))
end

function autodiff_setting()
    name = lowercase(get(ENV, "FIT2D_AUTODIFF", "finite"))
    name in ("finite", "finitediff", "central") && return (; name = "Optim/NLSolversBase central finite differences", autodiff = nothing)
    name in ("reverse", "reversediff") && return (; name = "ReverseDiff via ADTypes", autodiff = AutoReverseDiff())
    error("unknown FIT2D_AUTODIFF=$(name); expected finite or reversediff")
end

function selected_data()
    loaded = load_fit_data()
    sample_size = env_int("FIT2D_SAMPLE_SIZE", 250)
    sample_size <= 0 && return loaded.data2d
    return loaded.data2d[1:min(sample_size, length(loaded.data2d))]
end

data = selected_data()
constructor = build_2d_constructor(length(data))

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, data)

tolerance = env_float("FIT2D_TOLERANCE", 0.01)
errordef = 0.5
max_calls = env_int("FIT2D_MAX_CALLS", 500)
iterations = env_int("FIT2D_MAXITERS", 100)
memory = env_int("FIT2D_LBFGS_MEMORY", 10)
objective_budget = env_int("FIT2D_OBJECTIVE_CALL_BUDGET", 100_000)
ad = autodiff_setting()
objective_calls = Ref(0)
last_edm = Ref(Inf)

function counted_objective(pars)
    objective_calls[] += 1
    if objective_budget > 0 && objective_calls[] > objective_budget
        error("objective call budget exceeded: $(objective_calls[]) > $(objective_budget)")
    end
    return problem.objective(pars)
end

edm_goal = _minuit_edm_goal(tolerance = tolerance, errordef = errordef)
inner = LBFGS(m = memory, scaleinvH0 = false)
method = Fminbox(inner; precondprep = _descriptor_box_precondprep(problem))
options = Optim.Options(
    iterations = iterations,
    outer_iterations = iterations,
    f_calls_limit = max_calls,
    g_calls_limit = max_calls,
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
    callback = _optim_diagonal_edm_callback(problem, last_edm, edm_goal),
)

println("Yield-only Optim.Fminbox(LBFGS) fit")
println("events: ", length(data))
println("released: ", problem.names)
println("start: ", problem.start)
println("bounds: ", collect(zip(problem.lower, problem.upper)))
println("descriptor steps: ", problem.step)
println("preconditioner starts from step^2 diagonal through Fminbox barrier")
println("initial NLL: ", problem.base)
println("gradient: ", ad.name)
println("memory: ", memory, ", iterations: ", iterations, ", max calls: ", max_calls)
println("actual objective evaluation budget: ", objective_budget == 0 ? "none" : string(objective_budget))

result = if ad.autodiff === nothing
    optimize(counted_objective, problem.lower, problem.upper, problem.start, method, options)
else
    optimize(counted_objective, problem.lower, problem.upper, problem.start, method, options; autodiff = ad.autodiff)
end
BuildConstructors.update!(constructor, Optim.minimizer(result))

best_nll = problem.base + Optim.minimum(result)

println()
println("result:")
println("best pars: ", Optim.minimizer(result))
@printf("best NLL: %.12f\n", best_nll)
@printf("delta NLL: %.12f\n", best_nll - problem.base)
println("converged: ", Optim.converged(result))
println("stopped by: ", result.stopped_by)
println("diagonal EDM proxy: ", last_edm[])
println("counted objective calls: ", objective_calls[])
println("Optim f calls: ", Optim.f_calls(result))
println("Optim g calls: ", Optim.g_calls(result))
println("iterations: ", Optim.iterations(result))
