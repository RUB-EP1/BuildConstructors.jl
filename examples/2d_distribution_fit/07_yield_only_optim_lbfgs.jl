using Pkg

const SCRIPT_DIR = @__DIR__
Pkg.activate(SCRIPT_DIR)

include(joinpath(SCRIPT_DIR, "src", "two_dimensional_fit.jl"))

using BuildConstructors
using LinearAlgebra
using Optim
using Printf
using .TwoDimensionalFitExample

function env_int(name, default)
    return parse(Int, get(ENV, name, string(default)))
end

function env_float(name, default)
    return parse(Float64, get(ENV, name, string(default)))
end

function selected_data()
    loaded = load_fit_data()
    sample_size = env_int("FIT2D_SAMPLE_SIZE", 250)
    sample_size <= 0 && return loaded.data2d
    return loaded.data2d[1:min(sample_size, length(loaded.data2d))]
end

function descriptor_box_precondprep(problem)
    inverse_hessian_diagonal = map(collect(problem.step)) do step
        isfinite(step) && step > 0 ? step^2 : 0.01
    end
    hessian_diagonal = @. 1 / inverse_hessian_diagonal
    return function (P, x, lower, upper, dfbox)
        @. P.diag = 1 / (dfbox.mu * (1 / (x - lower)^2 + 1 / (upper - x)^2) + hessian_diagonal)
        return P
    end
end

function diagonal_edm_callback(problem, last_edm, tolerance, errordef)
    goal = max(2e-3 * tolerance * errordef, 4 * sqrt(eps()))
    inverse_hessian_diagonal = map(collect(problem.step)) do step
        isfinite(step) && step > 0 ? step^2 : 0.01
    end
    return function (state)
        if hasproperty(state, :g_x)
            last_edm[] = dot(state.g_x, inverse_hessian_diagonal .* state.g_x) / 2
            return isfinite(last_edm[]) && last_edm[] < goal
        end
        return false
    end
end

data = selected_data()
constructor = build_2d_constructor(length(data))

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, data)
densities = yield_component_densities(constructor, problem.start, data)

tolerance = env_float("FIT2D_TOLERANCE", 0.01)
errordef = 0.5
max_calls = env_int("FIT2D_MAX_CALLS", 500)
iterations = env_int("FIT2D_MAXITERS", 100)
memory = env_int("FIT2D_LBFGS_MEMORY", 10)
objective_calls = Ref(0)
gradient_calls = Ref(0)
last_edm = Ref(Inf)

function counted_objective(pars)
    objective_calls[] += 1
    return problem.objective(pars)
end

function counted_gradient!(gradient, pars)
    gradient_calls[] += 1
    return yield_only_gradient!(gradient, densities, pars)
end

inner = LBFGS(m = memory, scaleinvH0 = false)
method = Fminbox(inner; precondprep = descriptor_box_precondprep(problem))
objective = OnceDifferentiable(counted_objective, counted_gradient!, problem.start)
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
    callback = diagonal_edm_callback(problem, last_edm, tolerance, errordef),
)

println("Yield-only Optim.Fminbox(LBFGS) fit")
println("events: ", length(data))
println("released: ", problem.names)
println("start: ", problem.start)
println("bounds: ", collect(zip(problem.lower, problem.upper)))
println("descriptor steps: ", problem.step)
println("preconditioner starts from step^2 diagonal through Fminbox barrier")
println("initial NLL: ", problem.base)
println("gradient: analytic yield-only gradient")
println("memory: ", memory, ", iterations: ", iterations, ", max calls: ", max_calls)

result = optimize(objective, problem.lower, problem.upper, problem.start, method, options)
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
println("analytic gradient calls: ", gradient_calls[])
println("Optim f calls: ", Optim.f_calls(result))
println("Optim g calls: ", Optim.g_calls(result))
println("iterations: ", Optim.iterations(result))
