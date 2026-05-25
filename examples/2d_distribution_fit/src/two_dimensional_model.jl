using BuildConstructors
using Distributions
using DistributionsHEP: ExtendedMixtureModel
import DistributionsHEP: extended_negative_log_likelihood
using NumericalDistributions

const MASS_MIN_GEV = 1.002
const MASS_MAX_GEV = 1.038
const CCBAR_MIN_GEV = 2.80
const CCBAR_MAX_GEV = 4.00
const PHI_MASS_GEV = 1.019461

const CCBAR_LIMITS = (CCBAR_MIN_GEV, CCBAR_MAX_GEV)
const KK_LIMITS = (MASS_MIN_GEV, MASS_MAX_GEV)

@with_parameters(Fit2DTruncatedCrystalBall,
    mu::P, sigma::P, alpha::P, n::P,
    support::Tuple{Float64,Float64}, begin
        truncated(CrystalBall(mu, sigma, alpha, n), support...)
    end)

@with_parameters(Fit2DTruncatedExponential,
    k::P,
    support::Tuple{Float64,Float64}, begin
        s = sign(k)
        shift = s > 0 ? support[1] : support[2]
        truncated(shift + s * Exponential(s * k), support...)
    end)

@with_parameters(Fit2DExtendedKKComponents,
    y_phiphi::P, y_mixed::P, y_kkkk::P,
    signal_kk,
    background_kk,
    begin
        signal = build_model(signal_kk, pars)
        background = build_model(background_kk, pars)

        phiphi = product_distribution([signal, signal])
        mixed = MixtureModel(
            [
                product_distribution([signal, background]),
                product_distribution([background, signal]),
            ],
            [0.5, 0.5],
        )
        kkkk = product_distribution([background, background])

        return ExtendedMixtureModel([phiphi, mixed, kkkk], [y_phiphi, y_mixed, y_kkkk])
    end)

function extended_negative_log_likelihood(constructor::BuildConstructors.AbstractConstructor, pars, data)
    try
        return extended_negative_log_likelihood(build_model(constructor, pars), data)
    catch err
        err isa ArgumentError && return Inf
        rethrow()
    end
end
