using Pkg

const SCRIPT_DIR = @__DIR__
const PROJECT_ROOT = normpath(joinpath(SCRIPT_DIR, "..", ".."))
Pkg.activate(SCRIPT_DIR)

include(joinpath(SCRIPT_DIR, "src", "two_dimensional_fit.jl"))

using BuildConstructors
using ComponentArrays
using Optim
using .TwoDimensionalFitExample

loaded = load_fit_data()
constructor = build_2d_constructor(size(loaded.fit_df, 1))

start = ComponentArray(running_values(constructor))
initial_model = build_model(constructor, start)
initial_nll = extended_negative_log_likelihood(initial_model, loaded.data2d)

println("Events in fit window: ", size(loaded.fit_df, 1))
println("Initial parameters:")
show(stdout, MIME"text/plain"(), start)
println()
println("Initial extended NLL: ", initial_nll)

fix!(constructor)
release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
yield_fit = fit!(constructor, loaded.data2d; method = Fminbox(LBFGS()))

println()
println("Yield-only fit:")
show(stdout, MIME"text/plain"(), yield_fit.best_pars)
println()
println("Converged: ", Optim.converged(yield_fit.result))
println("Iterations: ", Optim.iterations(yield_fit.result))

fix!(constructor)
release!(constructor, (:mu_B,))
mass_fit = fit!(constructor, loaded.data2d; method = Fminbox(LBFGS()))

println()
println("Mass-only fit:")
show(stdout, MIME"text/plain"(), mass_fit.best_pars)
println()
println("Converged: ", Optim.converged(mass_fit.result))
println("Iterations: ", Optim.iterations(mass_fit.result))
