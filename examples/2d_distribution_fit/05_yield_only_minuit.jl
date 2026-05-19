using Pkg

const SCRIPT_DIR = @__DIR__
Pkg.activate(SCRIPT_DIR)

include(joinpath(SCRIPT_DIR, "src", "two_dimensional_fit.jl"))
include(joinpath(SCRIPT_DIR, "src", "Minuit2CAInterface.jl"))

using BuildConstructors
using Printf
using .Minuit2CAInterface
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

data = selected_data()
constructor = build_2d_constructor(length(data))

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
problem = fitting_problem(constructor, data)
objective = problem.objective

tolerance = env_float("FIT2D_TOLERANCE", 0.01)
max_calls = env_int("FIT2D_MAX_CALLS", 500)
strategy = env_int("FIT2D_MINUIT_STRATEGY", 1)

println("Yield-only Minuit2.Migrad fit")
println("events: ", length(data))
println("released: ", problem.names)
println("start: ", problem.start)
println("bounds: ", collect(zip(problem.lower, problem.upper)))
println("steps/errors: ", problem.step)
println("initial NLL: ", problem.base)
println("strategy: ", strategy, ", tolerance: ", tolerance, ", max calls: ", max_calls)

result = optimize(
    objective,
    problem.start,
    Minuit2CA(;
        strategy,
        tolerance,
        errordef = 0.5,
        maxcalls = max_calls,
        errors = problem.step,
        lower = problem.lower,
        upper = problem.upper,
        names = keys(problem.start),
    ),
)

BuildConstructors.update!(constructor, minimizer(result))

minuit = original(result)
best_nll = problem.base + minimum(result)

println()
println("result:")
println("best pars: ", minimizer(result))
@printf("best NLL: %.12f\n", best_nll)
@printf("delta NLL: %.12f\n", best_nll - problem.base)
println("converged: ", converged(result))
println("valid: ", result.valid)
println("reached call limit: ", result.reached_call_limit)
println("above max EDM: ", result.above_max_edm)
println("EDM: ", result.edm)
println("nfcn: ", result.objective_calls)
println("iterations: ", result.iterations)
println("underlying Minuit errors: ", minuit.errors)
