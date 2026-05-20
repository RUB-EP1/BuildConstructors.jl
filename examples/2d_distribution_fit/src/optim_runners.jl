function _optim_result(result; optim_edm = missing, converged = Optim.converged(result))
    return (;
        best_pars = Optim.minimizer(result),
        best_objective = Optim.minimum(result),
        converged,
        iterations = Optim.iterations(result),
        diagnostics = (; _missing_diagnostics()..., optim_edm),
    )
end

function _run_backend(
    ::Val{:optim},
    method_spec,
    objective,
    problem,
    constructor;
    maxiters,
    max_objective_calls,
    max_seconds,
)
    method = method_spec.method_factory()
    options = Optim.Options(iterations = maxiters)
    result = if method_spec.bounded
        optimize(objective, problem.lower, problem.upper, problem.start, method, options)
    else
        optimize(objective, problem.start, method, options)
    end
    BuildConstructors.update!(constructor, Optim.minimizer(result))
    return _optim_result(result)
end

function _minuit_like_optim_options(maxiters, max_objective_calls, max_seconds, callback)
    return Optim.Options(
        iterations = maxiters,
        outer_iterations = maxiters,
        f_calls_limit = max_objective_calls,
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

function _optimize_with_optional_autodiff(objective, lower, upper, start, method, options, settings)
    autodiff = get(settings, :autodiff, nothing)
    autodiff === nothing &&
        return optimize(objective, lower, upper, start, method, options)
    return optimize(objective, lower, upper, start, method, options; autodiff)
end

function _run_backend(
    ::Val{:optim_minuit_lbfgs},
    method_spec,
    objective,
    problem,
    constructor;
    maxiters,
    max_objective_calls,
    max_seconds,
)
    settings = method_spec.method_factory()
    edm_goal = _minuit_edm_goal(tolerance = settings.tolerance, errordef = settings.errordef)
    last_edm = Ref{Any}(Inf)
    options = _minuit_like_optim_options(
        maxiters,
        max_objective_calls,
        max_seconds,
        _optim_diagonal_edm_callback(problem, last_edm, edm_goal),
    )
    method = Fminbox(settings.method; precondprep = _descriptor_box_precondprep(problem))
    result = _optimize_with_optional_autodiff(
        objective,
        problem.lower,
        problem.upper,
        problem.start,
        method,
        options,
        settings,
    )
    BuildConstructors.update!(constructor, Optim.minimizer(result))
    return _optim_result(
        result;
        optim_edm = last_edm[],
        converged = Optim.converged(result) || (isfinite(last_edm[]) && last_edm[] < edm_goal),
    )
end

function _run_backend(
    ::Val{:optim_minuit_bfgs},
    method_spec,
    objective,
    problem,
    constructor;
    maxiters,
    max_objective_calls,
    max_seconds,
)
    settings = method_spec.method_factory()
    edm_goal = _minuit_edm_goal(tolerance = settings.tolerance, errordef = settings.errordef)
    last_edm = Ref{Any}(Inf)
    method = Fminbox(BFGS(initial_invH = _ -> _descriptor_inverse_hessian_matrix(problem)))
    options = _minuit_like_optim_options(
        maxiters,
        max_objective_calls,
        max_seconds,
        _optim_edm_callback(last_edm, edm_goal),
    )
    result = _optimize_with_optional_autodiff(
        objective,
        problem.lower,
        problem.upper,
        problem.start,
        method,
        options,
        settings,
    )
    BuildConstructors.update!(constructor, Optim.minimizer(result))
    return _optim_result(
        result;
        optim_edm = last_edm[],
        converged = Optim.converged(result) || (isfinite(last_edm[]) && last_edm[] < edm_goal),
    )
end
