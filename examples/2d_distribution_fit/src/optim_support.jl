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
