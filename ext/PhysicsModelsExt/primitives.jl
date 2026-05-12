# Physical
@with_parameters(
    BW;
    m::P,
    Γ::P,
    support::Tuple{Float64,Float64},
    begin
        NumericallyIntegrable(e->1/abs2(m^2-e^2 - 1im*m*Γ), _.support)
    end
)

@with_parameters(
    Braaten;
    γre::P,
    γim::P,
    support::Tuple{Float64,Float64},
    begin
        μ = 0.9666176144464419 # reduced mass of D0 and D*0 in GeV/c^2
        k1(E::Complex) = 1im * sqrt(-2μ * (E * 1e-3))
        k1(E::Real) = k1(E + 1e-7im)
        NumericallyIntegrable(e->1/abs2(-γre-1im*γim-1im*k1(e)), _.support)
    end
)


# Resolution

## Gaussian
@with_parameters(
    Gaussian;
    μ::P,
    σ::P,
    support::Tuple{Float64,Float64},
    begin
        truncated(Normal(μ, σ), _.support[1], _.support[2])
    end
)

## Crystal_Ball plus Hyperbolic_Secant
@with_parameters(
    CBpSECH;
    σ1::P,
    c0::P,
    c1::P,
    c2::P,
    n::P,
    s::P,
    fr1::P,
    w::P,
    support::Tuple{Float64,Float64},
    begin
        σ2 = s * σ1
        σ1_MeV, σ2_MeV = (σ1, σ2) .* 1e3
        α = c0 * (c1 * σ1)^c2 / (1 + (c1 * σ1)^c2)
        d1 = CrystalBall(0.0, σ1_MeV, α, n)
        td1 = truncated(d1, _.support[1], _.support[2])

        hyp_sec(x, μ, σ) = 1/(2*σ)*sech(π/2 * (x-μ)/σ)
        td2 = NumericallyIntegrable(x->hyp_sec(x, 0.0, σ2_MeV), _.support)
        # mixture model
        w * MixtureModel([td1, td2], [fr1, 1-fr1])
    end
)



# Background

## 1st order Chebyshev
@with_parameters(
    Pol1;
    c1C::P,
    support::Tuple{Float64,Float64},
    begin
        Chebyshev([1, c1C], _.support[1], _.support[2])
    end
)


## 2nd order Chebyshev
@with_parameters(
    Pol2;
    c1C::P,
    c2C::P,
    support::Tuple{Float64,Float64},
    begin
        Chebyshev([1, c1C, c2C], _.support[1], _.support[2])
    end
)
