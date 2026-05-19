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
    result = Minuit2CAInterface.optimize(
        objective,
        problem.start,
        Minuit2CAInterface.Minuit2CA(;
            strategy = settings.strategy,
            tolerance = settings.tolerance,
            errordef = 0.5,
            maxcalls = max_objective_calls,
            errors = problem.step,
            lower = problem.lower,
            upper = problem.upper,
            names = keys(problem.start),
            run_hesse = get(settings, :hesse, false),
        ),
    )
    BuildConstructors.update!(constructor, Minuit2CAInterface.minimizer(result))
    return (;
        best_pars = Minuit2CAInterface.minimizer(result),
        best_objective = Minuit2CAInterface.minimum(result),
        converged = Minuit2CAInterface.converged(result),
        iterations = result.iterations,
        diagnostics = (;
            _missing_diagnostics()...,
            minuit_edm = result.edm,
            minuit_nfcn = result.objective_calls,
            minuit_valid = result.valid,
            minuit_call_limit = result.reached_call_limit,
        ),
    )
end
