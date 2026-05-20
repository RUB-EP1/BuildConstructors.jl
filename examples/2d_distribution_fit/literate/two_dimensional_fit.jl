# # 2D Fit Model Definition
#
# This Literate source is the canonical definition of the imported
# `TwoDimensionalFitExample` module. It is generated into the runnable script
# `examples/2d_distribution_fit/src/two_dimensional_fit.jl` and into the
# documentation page `2D Fit Model Definition`.
#
# The module has four responsibilities:
#
# 1. Load the Arrow data table and apply the fit-window cuts.
# 2. Define reusable one-dimensional constructor blocks for the signal and
#    background mass shapes.
# 3. Assemble the two-dimensional extended mixture model.
# 4. Expose a small optimizer-facing problem object with named
#    `ComponentArray` starts, bounds, step scales, and objective.

module TwoDimensionalFitExample

using Arrow
using BuildConstructors
using ComponentArrays
using DataFrames
using Distributions
using DistributionsHEP
using NumericalDistributions
using Optim

import Distributions: logpdf

export CCBAR_LIMITS
export KK_LIMITS
export ExtendedMixtureModel
export build_2d_constructor
export data_path
export extended_negative_log_likelihood
export fit!
export fitting_problem
export free_parameter_names
export load_fit_data
export total_yield

const MASS_MIN_GEV = 1.002
const MASS_MAX_GEV = 1.038
const CCBAR_MIN_GEV = 2.80
const CCBAR_MAX_GEV = 4.00
const PHI_MASS_GEV = 1.019461

const CCBAR_LIMITS = (CCBAR_MIN_GEV, CCBAR_MAX_GEV)
const KK_LIMITS = (MASS_MIN_GEV, MASS_MAX_GEV)

data_path() = normpath(joinpath(@__DIR__, "..", "data", "fit_events.arrow"))

include("distributionshep_compat.jl")

# The original table stores masses in MeV. The fit uses GeV and keeps only the
# narrow `mKK` window around the phi mass. The returned `data2d` vector contains
# two-element vectors because the final model is a multivariate distribution.

function load_fit_data(path::AbstractString = data_path())
    isfile(path) || error("Missing Arrow table: $path")
    fit_df = DataFrame(Arrow.Table(path); copycols = true)

    transform!(
        fit_df,
        :mKK1 => ByRow(x -> x / 1e3) => :mKK1,
        :mKK2 => ByRow(x -> x / 1e3) => :mKK2,
    )

    subset!(
        fit_df,
        :mKK1 => x -> KK_LIMITS[1] .< x .< KK_LIMITS[2],
        :mKK2 => x -> KK_LIMITS[1] .< x .< KK_LIMITS[2],
    )

    data2d = collect.(zip(fit_df.mKK1, fit_df.mKK2))
    return (; fit_df, data2d)
end

# The one-dimensional building blocks are ordinary `BuildConstructors`
# constructors. Parameters declared as `::P` carry fit metadata; ordinary fields
# such as `support` are fixed configuration.

@with_parameters(Fit2DTruncatedCrystalBall,
    mu::P, sigma::P, alpha::P, n::P,
    support::Tuple{Float64,Float64}, begin
        truncated(_crystalball(mu, sigma, alpha, n), support...)
    end)

@with_parameters(Fit2DTruncatedExponential,
    k::P,
    support::Tuple{Float64,Float64}, begin
        s = sign(k)
        shift = s > 0 ? support[1] : support[2]
        truncated(shift + s * Exponential(s * k), support...)
    end)

@with_parameters(Fit2DChebyshev,
    a1::P, a2::P,
    support::Tuple{Float64,Float64}, begin
        Chebyshev([1.0, a1, a2], support...)
    end)

# `ExtendedMixtureModel` is a small distribution wrapper for extended
# likelihood fits. It stores component yields directly, rather than normalized
# mixture weights, and its density is the yield-weighted sum of component
# densities.

struct ExtendedMixtureModel{
    VF<:VariateForm,
    VS<:ValueSupport,
    C<:Distribution,
    RT<:Real,
} <: Distribution{VF,VS}
    components::Vector{C}
    yields::Vector{RT}

    function ExtendedMixtureModel{VF,VS,C,RT}(cs::Vector{C}, ys::Vector{RT}) where {VF,VS,C,RT}
        length(cs) == length(ys) ||
            throw(ArgumentError("ExtendedMixtureModel: $(length(cs)) components vs $(length(ys)) yields"))
        new{VF,VS,C,RT}(cs, ys)
    end
end

function ExtendedMixtureModel(cs::Vector{C}, ys::AbstractVector{<:Real}) where {C<:Distribution}
    length(cs) == length(ys) || throw(ArgumentError("ExtendedMixtureModel: length mismatch"))
    any(<(zero(eltype(ys))), ys) && throw(ArgumentError("ExtendedMixtureModel: yields must be non-negative"))
    VF = Distributions.variate_form(C)
    VS = Distributions.value_support(C)
    RT = promote_type(Float64, eltype(ys))
    return ExtendedMixtureModel{VF,VS,C,RT}(cs, Vector{RT}(ys))
end

Distributions.ncomponents(d::ExtendedMixtureModel) = length(d.components)
Distributions.components(d::ExtendedMixtureModel) = d.components
Distributions.component(d::ExtendedMixtureModel, k::Int) = d.components[k]
Distributions.component_type(d::ExtendedMixtureModel{VF,VS,C}) where {VF,VS,C} = C

yields(d::ExtendedMixtureModel) = d.yields
total_yield(d::ExtendedMixtureModel) = sum(yields(d))

function (::Type{MixtureModel})(d::ExtendedMixtureModel)
    total = total_yield(d)
    total > 0 || throw(ArgumentError("MixtureModel(::ExtendedMixtureModel): total yield must be positive"))
    return MixtureModel(components(d), yields(d) ./ total)
end

function Distributions.pdf(d::ExtendedMixtureModel{Multivariate}, x::AbstractVector{<:Real})
    return sum(yi * pdf(component(d, i), x) for (i, yi) in enumerate(yields(d)) if !iszero(yi))
end

function Distributions.logpdf(d::ExtendedMixtureModel{Multivariate}, x::AbstractVector{<:Real})
    density = pdf(d, x)
    return density <= 0 ? -Inf : log(density)
end

Base.length(d::ExtendedMixtureModel{Multivariate}) = length(d.components[1])

# The full 2D model has three extended-yield components:
#
# - signal in both axes,
# - signal/background plus background/signal with equal weights,
# - background in both axes.

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

# The extended negative log-likelihood is
#
# ```math
# -\sum_i \log\left(\sum_k y_k f_k(x_i)\right) + \sum_k y_k.
# ```
#
# Invalid physical regions, for example negative yields, are converted to
# `Inf` so minimizers can recover without crashing the entire benchmark.

function _finite_logpdf(model, x)
    lp = logpdf(model, x)
    return isfinite(lp) ? lp : -Inf
end

function extended_negative_log_likelihood(model, data)
    nll = 0.0
    for x in data
        lp = _finite_logpdf(model, x)
        isfinite(lp) || return Inf
        nll -= lp
    end
    return nll + total_yield(model)
end

function extended_negative_log_likelihood(constructor::BuildConstructors.AbstractConstructor, pars, data)
    try
        return extended_negative_log_likelihood(build_model(constructor, pars), data)
    catch err
        err isa ArgumentError && return Inf
        rethrow()
    end
end

# Only released parameters should enter the optimizer vector. Fixed descriptors
# keep their stored values and are deliberately excluded from the
# `ComponentArray` given to Optim or Minuit.

function _append_free_parameter_names!(names::Vector{Symbol}, p::BuildConstructors.AbstractParameter)
    isempty(running_values(p)) && return names
    fixed = hasfield(typeof(p), :fixed) ? getfield(p, :fixed) : false
    fixed || append!(names, keys(running_values(p)))
    return names
end

function _append_free_parameter_names!(names::Vector{Symbol}, c::BuildConstructors.AbstractConstructor)
    for field in fieldnames(typeof(c))
        _append_free_parameter_names!(names, getfield(c, field))
    end
    return names
end

_append_free_parameter_names!(names::Vector{Symbol}, _) = names

function free_parameter_names(constructor::BuildConstructors.AbstractConstructor)
    names = Symbol[]
    _append_free_parameter_names!(names, constructor)
    return Tuple(unique(names))
end

# `fitting_problem` is the bridge from constructor metadata to minimizer inputs.
# The descriptor uncertainty becomes the optimizer scale / Minuit error. It is
# not used as a finite-difference perturbation.

function _select_parameters(values, names::Tuple)
    return NamedTuple{names}(map(name -> getproperty(values, name), names))
end

function fitting_problem(constructor, data)
    names = free_parameter_names(constructor)
    isempty(names) && error("No released parameters to fit")

    start = ComponentArray(_select_parameters(running_values(constructor), names))
    lower = ComponentArray(_select_parameters(running_lower_boundaries(constructor), names))
    upper = ComponentArray(_select_parameters(running_upper_boundaries(constructor), names))
    step = ComponentArray(
        _select_parameters(
            map(value -> ismissing(value) ? 0.1 : value, running_uncertainties(constructor)),
            names,
        ),
    )

    base = extended_negative_log_likelihood(constructor, start, data)
    objective(p) = extended_negative_log_likelihood(constructor, p, data) - base
    return (; names, start, lower, upper, step, base, objective)
end

# These starting values are intentionally imperfect but physically sensible.
# Bounds protect the extended NLL from invalid probes, and uncertainties provide
# the initial metric scale for Minuit-like configurations.

function build_2d_constructor(n_events::Integer)
    signal_kk = ConstructorOfFit2DTruncatedCrystalBall(
        AdvancedParameter("mu_B", 1.002 * PHI_MASS_GEV; boundaries = KK_LIMITS, uncertainty = 1e-4),
        AdvancedParameter("sigma_B", 0.0025; boundaries = (1e-4, 0.02), uncertainty = 2e-4),
        AdvancedParameter("alpha_B", 2.0; boundaries = (0.2, 10.0), uncertainty = 0.1),
        Fixed(2.5),
        KK_LIMITS,
    )

    background_kk = ConstructorOfFit2DTruncatedExponential(
        AdvancedParameter("k_bkg_kk", -0.2; boundaries = (-50.0, -1e-6), uncertainty = 0.05),
        KK_LIMITS,
    )

    return ConstructorOfFit2DExtendedKKComponents(
        signal_kk,
        background_kk,
        AdvancedParameter("y_phiphi", 0.3 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
        AdvancedParameter("y_mixed", 0.1 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
        AdvancedParameter("y_kkkk", 0.6 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    )
end

# This is the smallest general-purpose Optim entry point. The study notebooks
# define richer runners inline so the effect of each minimizer setting remains
# visible.

function fit!(
    constructor,
    data;
    method = Fminbox(LBFGS()),
    options = Optim.Options(iterations = 1_000),
)
    problem = fitting_problem(constructor, data)

    result = optimize(
        problem.objective,
        problem.lower,
        problem.upper,
        problem.start,
        method,
        options,
    )
    BuildConstructors.update!(constructor, Optim.minimizer(result))
    return (; result, best_pars = Optim.minimizer(result))
end

end
