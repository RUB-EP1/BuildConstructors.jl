# Minimal CrystalBall and Chebyshev distributions adapted from DistributionsHEP.jl.
# https://github.com/JuliaHEP/DistributionsHEP.jl (MIT)

using Distributions
using Polynomials
using SpecialFunctions

import Distributions: pdf, cdf, quantile, minimum, maximum

function _check_crystalball_params(σ::T, α::T, n::T) where {T <: Real}
    σ > zero(T) || error("σ (scale) must be positive.")
    α > zero(T) || error("α (transition point) must be positive.")
    n > one(T) || error("n (power-law exponent) must be greater than 1.")
end

struct CrystalBall{T <: Real} <: ContinuousUnivariateDistribution
    μ::T
    σ::T
    α::T
    n::T
    norm_const::T
    A_const::T
    B_const::T

    function CrystalBall(μ::T, σ::T, α::T, n::T) where {T <: Real}
        _check_crystalball_params(σ, α, n)
        C = n / α / (n - 1) * exp(-α^2 / 2)
        D_val = sqrt(T(π) / 2) * (one(T) + erf(α / sqrt(T(2))))
        N = one(T) / (C + D_val)
        A = (n / α)^n * exp(-α^2 / 2)
        B = n / α - α
        new{T}(μ, σ, α, n, N, A, B)
    end
end

function pdf(d::CrystalBall{T}, x::Real) where {T <: Real}
    x̂ = (x - d.μ) / d.σ
    x̂ > -d.α && return d.norm_const * exp(-x̂^2 / 2) / d.σ
    return d.norm_const * d.A_const * (d.B_const - x̂)^(-d.n) / d.σ
end

function cdf(d::CrystalBall{T}, x::Real) where {T <: Real}
    x̂ = (x - d.μ) / d.σ
    cdf_at_minus_alpha =
        d.norm_const * d.A_const / (d.n - 1) * (d.B_const - (-d.α))^(1 - d.n)
    if x̂ <= -d.α
        return d.norm_const * d.A_const / (d.n - 1) * (d.B_const - x̂)^(1 - d.n)
    else
        integral_gaussian_part =
            sqrt(T(π) / 2) * (erf(x̂ / sqrt(T(2))) + erf(d.α / sqrt(T(2))))
        return cdf_at_minus_alpha + d.norm_const * integral_gaussian_part
    end
end

function quantile(d::CrystalBall{T}, p::Real) where {T <: Real}
    if p < zero(T) || p > one(T)
        throw(DomainError(p, "Probability p must be in [0,1]."))
    end
    p == zero(T) && return T(-Inf)
    p == one(T) && return T(Inf)

    cdf_at_minus_alpha = cdf(d, d.μ - d.α * d.σ)
    x̂ = zero(T)
    if p <= cdf_at_minus_alpha
        base = (p * (d.n - 1)) / (d.norm_const * d.A_const)
        x̂ = d.B_const - base^(one(T) / (one(T) - d.n))
    else
        term_for_erfinv_num = (p - cdf_at_minus_alpha)
        term_for_erfinv_den = d.norm_const * sqrt(T(π) / T(2))
        erf_alpha_sqrt2 = erf(d.α / sqrt(T(2)))
        arg_erfinv = (term_for_erfinv_num / term_for_erfinv_den) - erf_alpha_sqrt2
        x̂ = sqrt(T(2)) * erfinv(arg_erfinv)
    end
    return d.μ + d.σ * x̂
end

maximum(d::CrystalBall{T}) where {T <: Real} = T(Inf)
minimum(d::CrystalBall{T}) where {T <: Real} = T(-Inf)

struct StandardChebyshev <: ContinuousUnivariateDistribution
    polynomial::ChebyshevT{Float64, :x}
    integral::Float64
    function StandardChebyshev(coeffs)
        polynomial = ChebyshevT(coeffs)
        integral = integrate(polynomial)
        new(polynomial, (integral(1.0) - integral(-1.0)))
    end
end

function Chebyshev(coeffs, a::T = -1.0, b::T = 1.0) where {T <: Real}
    return StandardChebyshev(coeffs) * (b - a) / 2 + (a + b) / 2
end

minimum(d::StandardChebyshev) = -1.0
maximum(d::StandardChebyshev) = 1.0

pdf(d::StandardChebyshev, x::Real) = d.polynomial(x) / d.integral
cdf(d::StandardChebyshev, x::Real) = integrate(d.polynomial, -1.0, x) / d.integral
