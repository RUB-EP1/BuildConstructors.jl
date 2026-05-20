# Local compatibility shims for DistributionsHEP behavior that should move
# upstream once the corresponding package issues are resolved.

# DistributionsHEP's CrystalBall currently provides `pdf` but not `logpdf`.
function logpdf(d::CrystalBall{T}, x::Real) where {T<:Real}
    p = pdf(d, x)
    return p <= 0 ? -Inf : log(p)
end

# CrystalBall requires all constructor parameters to have exactly the same
# numeric type. ReverseDiff commonly traces only the released parameters, so
# fixed Float64 parameters need promotion to the tracked scalar type.
function _crystalball(mu, sigma, alpha, n)
    T = promote_type(typeof(mu), typeof(sigma), typeof(alpha), typeof(n))
    return CrystalBall(T(mu), T(sigma), T(alpha), T(n))
end
