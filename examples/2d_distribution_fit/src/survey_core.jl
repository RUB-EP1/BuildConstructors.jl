struct BudgetExceeded <: Exception
    reason::String
end

struct MethodSpec
    name::String
    method_factory::Function
    bounded::Bool
    backend::Symbol
    notes::String
end

MethodSpec(name::String, method_factory::Function, bounded::Bool, notes::String) =
    MethodSpec(name, method_factory, bounded, :optim, notes)

struct StageSpec
    name::String
    release::Tuple{Vararg{Symbol}}
    notes::String
end

function default_stage_specs()
    return StageSpec[
        StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "Release only extended yields."),
        StageSpec("mass_only", (:mu_B,), "Release the signal mass after the yield stage."),
        StageSpec("shape_only", (:sigma_B, :alpha_B, :k_bkg_kk), "Release width, tail, and background slope."),
        StageSpec("all_free", (:y_phiphi, :y_mixed, :y_kkkk, :mu_B, :sigma_B, :alpha_B, :k_bkg_kk), "Stress test: release all fit parameters."),
    ]
end

_missing_diagnostics() = (;
    minuit_edm = missing,
    minuit_nfcn = missing,
    minuit_valid = missing,
    minuit_call_limit = missing,
    optim_edm = missing,
)

function _make_constructor(n_events, warm_start)
    constructor = build_2d_constructor(n_events)
    warm_start === nothing || BuildConstructors.update!(constructor, warm_start)
    return constructor
end

function _budgeted_objective(objective; max_objective_calls, max_seconds)
    started = time()
    calls = Ref(0)
    best_value = Ref(Inf)
    best_pars = Ref{Any}(nothing)

    budgeted = function (pars)
        calls[] += 1
        calls[] > max_objective_calls &&
            throw(BudgetExceeded("objective call budget exceeded"))
        time() - started > max_seconds &&
            throw(BudgetExceeded("wall-time budget exceeded"))
        value = objective(pars)
        if isfinite(value) && value < best_value[]
            best_value[] = value
            best_pars[] = deepcopy(pars)
        end
        return value
    end

    return budgeted, calls, started, best_value, best_pars
end

function _run_backend end

function _run_one_stage(
    method_spec,
    stage,
    data;
    warm_start = nothing,
    maxiters = 100,
    max_objective_calls = 1_000,
    max_seconds = 30.0,
)
    constructor = _make_constructor(length(data), warm_start)
    fix!(constructor)
    release!(constructor, stage.release)
    problem = fitting_problem(constructor, data)
    objective, objective_calls, started, best_value, best_observed_pars = _budgeted_objective(
        problem.objective;
        max_objective_calls,
        max_seconds,
    )

    errored = false
    budget_exceeded = false
    budget_reason = ""
    error_type = ""
    error_message = ""
    outcome = nothing

    try
        outcome = _run_backend(
            Val(method_spec.backend),
            method_spec,
            objective,
            problem,
            constructor;
            maxiters,
            max_objective_calls,
            max_seconds,
        )
    catch err
        errored = true
        error_type = string(typeof(err))
        error_message = sprint(showerror, err)
        if err isa BudgetExceeded
            budget_exceeded = true
            budget_reason = err.reason
        end
    end

    diagnostics = outcome === nothing ? _missing_diagnostics() : outcome.diagnostics
    best_pars = if outcome === nothing
        best_observed_pars[] === nothing ? problem.start : best_observed_pars[]
    else
        outcome.best_pars
    end
    best_objective = outcome === nothing ? best_value[] : outcome.best_objective
    best_nll = isfinite(best_objective) ? problem.base + best_objective : Inf

    return (;
        timestamp = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
        stage = stage.name,
        released = join(string.(stage.release), " "),
        method = method_spec.name,
        bounded = method_spec.bounded,
        n_events = length(data),
        maxiters,
        max_objective_calls,
        max_seconds,
        objective_calls = objective_calls[],
        elapsed_seconds = time() - started,
        converged = errored ? false : outcome.converged,
        iterations = errored ? missing : outcome.iterations,
        minimum = best_objective,
        best_nll,
        diagnostics.minuit_edm,
        diagnostics.minuit_nfcn,
        diagnostics.minuit_valid,
        diagnostics.minuit_call_limit,
        diagnostics.optim_edm,
        errored,
        budget_exceeded,
        budget_reason,
        error_type,
        error_message,
        best_pars = string(best_pars),
        stage_notes = stage.notes,
        method_notes = method_spec.notes,
    )
end

function run_survey(
    data;
    stages = default_stage_specs(),
    methods = default_method_specs(),
    maxiters = 100,
    max_objective_calls = 1_000,
    max_seconds = 30.0,
    warm_start = nothing,
)
    results = NamedTuple[]
    for stage in stages
        for method in methods
            @info "Running minimizer survey" stage = stage.name method = method.name n_events = length(data) maxiters max_objective_calls max_seconds
            push!(
                results,
                _run_one_stage(
                    method,
                    stage,
                    data;
                    warm_start,
                    maxiters,
                    max_objective_calls,
                    max_seconds,
                ),
            )
        end
    end
    return results
end

function _csv_escape(value)
    text = string(value)
    return "\"" * replace(text, "\"" => "\"\"") * "\""
end

function write_results_csv(path::AbstractString, results; append::Bool = false)
    isempty(results) && error("No results to write")
    mkpath(dirname(path))
    keys_ = keys(first(results))
    write_header = !(append && isfile(path) && filesize(path) > 0)
    open(path, append ? "a" : "w") do io
        write_header && println(io, join(keys_, ","))
        for row in results
            println(io, join((_csv_escape(getproperty(row, key)) for key in keys_), ","))
        end
    end
    return path
end

function _scoreboard_status(row)
    row.converged && return "ok"
    row.budget_exceeded && return "budget"
    row.errored && return "error"
    return "no"
end

function _scoreboard_edm(row)
    if !ismissing(row.minuit_edm)
        return row.minuit_edm
    elseif !ismissing(row.optim_edm)
        return row.optim_edm
    end
    return missing
end

_scoreboard_number(value; digits = 3) =
    ismissing(value) ? "" : isfinite(value) ? string(round(value; digits)) : string(value)

function _ranked_scoreboard_rows(results)
    finite_rows = filter(row -> isfinite(row.best_nll), results)
    other_rows = filter(row -> !isfinite(row.best_nll), results)
    return vcat(sort(finite_rows; by = row -> row.best_nll), other_rows)
end

function write_markdown_summary(path::AbstractString, results)
    isempty(results) && error("No results to summarize")
    mkpath(dirname(path))
    ranked_results = _ranked_scoreboard_rows(results)
    best_nll = first(ranked_results).best_nll
    open(path, "w") do io
        println(io, "# 2D fit minimizer survey")
        println(io)
        println(io, "Generated: ", Dates.format(now(), dateformat"yyyy-mm-dd HH:MM:SS"))
        println(io)
        println(io, "| rank | stage | method | status | best NLL | ΔNLL | calls | sec | edm |")
        println(io, "| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |")
        for (rank, row) in enumerate(ranked_results)
            delta_nll = isfinite(row.best_nll) && isfinite(best_nll) ? row.best_nll - best_nll : missing
            @printf(
                io,
                "| %d | %s | %s | %s | %s | %s | %d | %.3f | %s |\n",
                rank,
                row.stage,
                row.method,
                _scoreboard_status(row),
                _scoreboard_number(row.best_nll; digits = 6),
                _scoreboard_number(delta_nll; digits = 6),
                row.objective_calls,
                row.elapsed_seconds,
                _scoreboard_number(_scoreboard_edm(row); digits = 6),
            )
        end
        println(io)
        println(io, "Status: `ok` converged, `budget` hit the configured computation budget, `error` threw before convergence, `no` stopped without convergence.")
    end
    return path
end
