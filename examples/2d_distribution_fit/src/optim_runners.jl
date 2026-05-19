function _finite_difference_gradient!(gradient, objective, problem, pars)
    fx = objective(pars)
    for i in eachindex(pars)
        step = problem.step[i]
        isfinite(step) && step > 0 || (step = 0.1)
        lower = problem.lower[i]
        upper = problem.upper[i]

        plus = copy(pars)
        minus = copy(pars)
        if pars[i] - step >= lower && pars[i] + step <= upper
            plus[i] = pars[i] + step
            minus[i] = pars[i] - step
            fp = objective(plus)
            fm = objective(minus)
            gradient[i] = (fp - fm) / (2step)
        elseif pars[i] + step <= upper
            plus[i] = pars[i] + step
            fp = objective(plus)
            gradient[i] = (fp - fx) / step
        elseif pars[i] - step >= lower
            minus[i] = pars[i] - step
            fm = objective(minus)
            gradient[i] = (fx - fm) / step
        else
            gradient[i] = 0.0
        end
    end
    return gradient
end

_minuit_edm_goal(; tolerance, errordef) = max(2e-3 * tolerance * errordef, 4 * sqrt(eps()))

function _descriptor_inverse_hessian(problem)
    diagonal = map(collect(problem.step)) do step
        isfinite(step) && step > 0 ? step^2 : 0.01
    end
    return Diagonal(diagonal)
end

_descriptor_inverse_hessian_matrix(problem) = Matrix(_descriptor_inverse_hessian(problem))

function _descriptor_box_precondprep(problem)
    inverse_hessian_diagonal = diag(_descriptor_inverse_hessian(problem))
    hessian_diagonal = @. 1 / inverse_hessian_diagonal
    return function (P, x, lower, upper, dfbox)
        @. P.diag = 1 / (dfbox.mu * (1 / (x - lower)^2 + 1 / (upper - x)^2) + hessian_diagonal)
        return P
    end
end

function _optim_edm_callback(last_edm, goal)
    return function (state)
        if hasproperty(state, :g_x) && hasproperty(state, :invH)
            gradient = state.g_x
            inv_hessian = state.invH
            last_edm[] = dot(gradient, inv_hessian * gradient) / 2
            return isfinite(last_edm[]) && last_edm[] < goal
        end
        return false
    end
end

function _optim_diagonal_edm_callback(problem, last_edm, goal)
    inverse_hessian_diagonal = diag(_descriptor_inverse_hessian(problem))
    return function (state)
        if hasproperty(state, :g_x)
            gradient = state.g_x
            last_edm[] = dot(gradient, inverse_hessian_diagonal .* gradient) / 2
            return isfinite(last_edm[]) && last_edm[] < goal
        end
        return false
    end
end

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

function _run_backend(
    ::Val{:optim_descriptor_steps},
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
    gradient! = (gradient, pars) -> _finite_difference_gradient!(gradient, objective, problem, pars)
    od = OnceDifferentiable(objective, gradient!, problem.start)
    result = optimize(od, problem.lower, problem.upper, problem.start, method, options)
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
        callback,
    )
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
    gradient! = (gradient, pars) -> _finite_difference_gradient!(gradient, objective, problem, pars)
    od = OnceDifferentiable(objective, gradient!, problem.start)
    method = Fminbox(settings.method; precondprep = _descriptor_box_precondprep(problem))
    result = optimize(od, problem.lower, problem.upper, problem.start, method, options)
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
    gradient! = (gradient, pars) -> _finite_difference_gradient!(gradient, objective, problem, pars)
    od = OnceDifferentiable(objective, gradient!, problem.start)
    result = optimize(od, problem.lower, problem.upper, problem.start, method, options)
    BuildConstructors.update!(constructor, Optim.minimizer(result))
    return _optim_result(
        result;
        optim_edm = last_edm[],
        converged = Optim.converged(result) || (isfinite(last_edm[]) && last_edm[] < edm_goal),
    )
end
