# 2D Default Optimizer Survey

Default optimizer rows are negative controls. They answer a practical user
question: what happens if the model is fitted with obvious, lightly configured
methods?

This notebook implements the small survey machinery directly instead of
importing the benchmark harness. The production harness in
`examples/2d_distribution_fit/src` is the same idea split into reusable files.

````julia
using Dates
using Optim

include(joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
using .TwoDimensionalFitExample
````

A stage is just the set of constructor parameters released for one attempt.

````julia
struct StageSpec
    name::String
    release::Tuple{Vararg{Symbol}}
end

const ALL_FIT_PARAMETERS = (
    :y_phiphi,
    :y_mixed,
    :y_kkkk,
    :mu_B,
    :sigma_B,
    :alpha_B,
    :k_bkg_kk,
)

all_free_stage = StageSpec("all_free", ALL_FIT_PARAMETERS)
````

A method specification names the method and stores the factory that builds it.
Keeping this data-driven makes it easy to add rows to the scoreboard.

````julia
struct MethodSpec
    name::String
    method_factory::Function
    bounded::Bool
end

default_methods = MethodSpec[
    MethodSpec("Optim.Fminbox(LBFGS())", () -> Fminbox(LBFGS()), true),
    MethodSpec("Optim.Fminbox(BFGS())", () -> Fminbox(BFGS()), true),
    MethodSpec("Optim.NelderMead()", () -> NelderMead(), false),
    MethodSpec("Optim.ParticleSwarm()", () -> ParticleSwarm(), false),
]
````

Every attempt gets a hard objective-call and wall-time budget. Slow methods
should produce a recorded budget outcome, not an unbounded notebook run.

````julia
struct BudgetExceeded <: Exception
    reason::String
end

function budgeted_objective(objective; max_calls, max_seconds)
    started = time()
    calls = Ref(0)
    best_value = Ref(Inf)

    wrapped = function (pars)
        calls[] += 1
        calls[] > max_calls && throw(BudgetExceeded("objective call budget exceeded"))
        time() - started > max_seconds && throw(BudgetExceeded("wall-time budget exceeded"))
        value = objective(pars)
        value isa AbstractFloat && isfinite(value) && value < best_value[] && (best_value[] = value)
        return value
    end

    return wrapped, calls, started, best_value
end
````

This tiny runner is enough to compare default Optim methods. Bounded methods
receive `lower`, `upper`, and `start`; unbounded methods receive only `start`.

````julia
function run_default_row(method::MethodSpec, stage::StageSpec, data; maxiters = 25, max_calls = 500, max_seconds = 20.0)
    constructor = build_2d_constructor(length(data))
    fix!(constructor)
    release!(constructor, stage.release)
    problem = fitting_problem(constructor, data)
    objective, calls, started, best_value = budgeted_objective(problem.objective; max_calls, max_seconds)

    errored = false
    error_message = ""
    result = nothing
    try
        options = Optim.Options(iterations = maxiters, f_calls_limit = max_calls, time_limit = max_seconds)
        result = method.bounded ?
            optimize(objective, problem.lower, problem.upper, problem.start, method.method_factory(), options) :
            optimize(objective, problem.start, method.method_factory(), options)
    catch err
        errored = true
        error_message = sprint(showerror, err)
    end

    best_objective = result === nothing ? best_value[] : Optim.minimum(result)
    return (;
        timestamp = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
        stage = stage.name,
        method = method.name,
        converged = result !== nothing && Optim.converged(result),
        errored,
        error_message,
        calls = calls[],
        seconds = time() - started,
        best_nll = isfinite(best_objective) ? problem.base + best_objective : Inf,
    )
end

loaded = load_fit_data()
rows = [
    run_default_row(method, all_free_stage, loaded.data2d[1:250])
    for method in default_methods
]
````

The default rows should sit beside the tuned rows in the scoreboard. If they
fail to get close to the best NLL inside the same budget, that is useful
documentation: the optimizer was not given enough scale information for this
constrained extended likelihood.

