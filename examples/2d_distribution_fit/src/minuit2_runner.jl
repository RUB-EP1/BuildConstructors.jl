function _run_backend(
    ::Val{:minuit},
    method_spec,
    objective,
    problem,
    constructor;
    maxiters,
    max_objective_calls,
    max_seconds,
)
    settings = method_spec.method_factory()
    minuit = Minuit(
        objective,
        problem.start;
        names = string.(keys(problem.start)),
        limits = collect(zip(problem.lower, problem.upper)),
        error = collect(problem.step),
        arraycall = true,
        errordef = 0.5,
        tolerance = settings.tolerance,
    )
    migrad!(minuit, settings.strategy; ncall = max_objective_calls)
    get(settings, :hesse, false) && hesse!(minuit)
    BuildConstructors.update!(constructor, minuit.values)
    return (;
        best_pars = minuit.values,
        best_objective = minuit.fval,
        converged = minuit.is_valid && !minuit.has_reached_call_limit && !minuit.is_above_max_edm,
        iterations = minuit.niter,
        diagnostics = (;
            _missing_diagnostics()...,
            minuit_edm = minuit.edm,
            minuit_nfcn = minuit.nfcn,
            minuit_valid = minuit.is_valid,
            minuit_call_limit = minuit.has_reached_call_limit,
        ),
    )
end
