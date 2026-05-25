# # 2D Model Construction
#
# This tutorial builds a two-dimensional extended mass model directly from
# `BuildConstructors` descriptors. It stops at model construction, data loading,
# metadata inspection, and plotting; minimizer setup belongs in separate
# tutorials.
#
# The example uses `src/two_dimensional_model.jl` for constructor types,
# constants, and a thin wrapper around `DistributionsHEP.extended_negative_log_likelihood`.
# `ExtendedMixtureModel`, `marginalize`, and the extended NLL live in
# `DistributionsHEP.jl` (pinned to branch `codex/extended-mixture-model`).
#
# ## How `two_dimensional_model.jl` defines the model
#
# The model shapes are declared once in
# `examples/2d_distribution_fit/src/two_dimensional_model.jl` with
# [`@with_parameters`](@ref). Each macro block generates two things:
#
# - a `ConstructorOf…` struct that stores parameter descriptors and nested
#   constructors, and
# - a matching `build_model(::ConstructorOf…, pars)` method whose body turns
#   those descriptors into an ordinary `Distributions.jl` object.
#
# Inside a `@with_parameters` body, fields fall into three roles:
#
# - `field::P` — fit parameter. The macro resolves it to a numeric value from
#   `pars` and exposes it as a local named `field`.
# - `field::SomeType` — fixed configuration stored on the constructor (for
#   example a fit window or a fixed tail index).
# - `field` without `::P` — nested constructor. Pass the same `pars` through
#   when calling `build_model(field, pars)`.
#
# The constructor positional arguments follow the same order as the field list in
# the macro header.
#
# ### Constants and fit windows
#
# The source file fixes the φ-region K⁺K⁻ mass window in GeV:
#
# ```julia
# const KK_LIMITS = (1.002, 1.038)
# const PHI_MASS_GEV = 1.019461
# ```
#
# The tutorial reuses `KK_LIMITS` when loading data and when building
# constructors.
#
# ### One-dimensional signal: `Fit2DTruncatedCrystalBall`
#
# The signal component is a truncated `CrystalBall` on the KK mass axis:
#
# ```julia
# @with_parameters(Fit2DTruncatedCrystalBall,
#     mu::P, sigma::P, alpha::P, n::P,
#     support::Tuple{Float64,Float64}, begin
#         truncated(CrystalBall(mu, sigma, alpha, n), support...)
#     end)
# ```
#
# `mu`, `sigma`, `alpha`, and `n` become fit parameters. `support` is fixed to
# `KK_LIMITS` when the constructor is built below. `n` is wrapped in
# `BuildConstructors.Fixed` in the tutorial so the tail index stays constant for
# this example.
#
# ### One-dimensional background: `Fit2DTruncatedExponential`
#
# The background is a truncated exponential, oriented according to the sign of
# `k`:
#
# ```julia
# @with_parameters(Fit2DTruncatedExponential,
#     k::P,
#     support::Tuple{Float64,Float64}, begin
#         s = sign(k)
#         shift = s > 0 ? support[1] : support[2]
#         truncated(shift + s * Exponential(s * k), support...)
#     end)
# ```
#
# Only the decay rate `k` is free; the support window is again supplied as
# `KK_LIMITS` at construction time.
#
# ### Extended two-dimensional assembly: `Fit2DExtendedKKComponents`
#
# The top-level constructor combines three **yield components** for the two KK
# invariant masses `(m₁, m₂)`:
#
# | Component | Physics picture | 2D shape |
# |:--|:--|:--|
# | `phiphi` | signal on both axes | `signal × signal` |
# | `mixed` | signal on one axis, background on the other | equal mix of `signal × background` and `background × signal` |
# | `kkkk` | background on both axes | `background × background` |
#
# The macro body builds the 1D shapes, forms 2D products with
# `product_distribution`, and wraps the result in `ExtendedMixtureModel`:
#
# ```julia
# @with_parameters(Fit2DExtendedKKComponents,
#     y_phiphi::P, y_mixed::P, y_kkkk::P,
#     signal_kk,
#     background_kk,
#     begin
#         signal = build_model(signal_kk, pars)
#         background = build_model(background_kk, pars)
#
#         phiphi = product_distribution([signal, signal])
#         mixed = MixtureModel(
#             [
#                 product_distribution([signal, background]),
#                 product_distribution([background, signal]),
#             ],
#             [0.5, 0.5],
#         )
#         kkkk = product_distribution([background, background])
#
#         return ExtendedMixtureModel([phiphi, mixed, kkkk], [y_phiphi, y_mixed, y_kkkk])
#     end)
# ```
#
# The three `y_*` fields are extended yields: the model predicts absolute event
# counts, not just a normalized PDF. Because the macro lists the yields before
# the nested constructors, the generated constructor is called as
# `ConstructorOfFit2DExtendedKKComponents(y_phiphi, y_mixed, y_kkkk, signal_kk, background_kk)`.
#
# ### Negative log-likelihood wrapper
#
# The source file adds a convenience method so callers can pass the constructor
# tree directly:
#
# ```julia
# function extended_negative_log_likelihood(constructor::AbstractConstructor, pars, data)
#     try
#         return extended_negative_log_likelihood(build_model(constructor, pars), data)
#     catch err
#         err isa ArgumentError && return Inf
#         rethrow()
#     end
# end
# ```
#
# If `build_model` rejects the trial parameters, the wrapper returns `Inf`
# instead of aborting the surrounding minimizer logic.
#
# The next cell loads that file and registers the generated constructor types in
# the tutorial session.

using Arrow
using BuildConstructors
using DataFrames
using Distributions
using DistributionsHEP
using Plots

example_dir = joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit")
model_source = joinpath(example_dir, "src", "two_dimensional_model.jl")

include(model_source)

# ## Load the data
#
# The Arrow fixture stores the two K+K- masses in MeV. The model constants are
# in GeV, so the conversion and the fit-window cuts are intentionally visible
# here instead of hidden behind a helper function.

fit_events_path = joinpath(example_dir, "data", "fit_events.arrow")
fit_df = DataFrame(Arrow.Table(fit_events_path); copycols = true)

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
n_events = length(data2d)

# ## Build the one-dimensional components
#
# The `@with_parameters` blocks above generated
# `ConstructorOfFit2DTruncatedCrystalBall` and
# `ConstructorOfFit2DTruncatedExponential`. Here we supply starting values,
# bounds, and uncertainties for the fit parameters. `AdvancedParameter` carries
# that metadata; `Fixed` marks a value that stays constant for this model.

signal_kk = ConstructorOfFit2DTruncatedCrystalBall(
    AdvancedParameter("mu_B", 1.002 * PHI_MASS_GEV; boundaries = KK_LIMITS, uncertainty = 1e-4),
    AdvancedParameter("sigma_B", 0.0025; boundaries = (1e-4, 0.02), uncertainty = 2e-4),
    AdvancedParameter("alpha_B", 2.0; boundaries = (0.2, 10.0), uncertainty = 0.1),
    BuildConstructors.Fixed(2.5),
    KK_LIMITS,
)

background_kk = ConstructorOfFit2DTruncatedExponential(
    AdvancedParameter("k_bkg_kk", -0.2; boundaries = (-50.0, -1e-6), uncertainty = 0.05),
    KK_LIMITS,
)

# ## Assemble the extended 2D model
#
# `ConstructorOfFit2DExtendedKKComponents` follows the macro field order: yields
# first, then the nested 1D constructors defined above.

full_model_constructor = ConstructorOfFit2DExtendedKKComponents(
    AdvancedParameter("y_phiphi", 0.3 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_mixed", 0.1 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_kkkk", 0.6 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    signal_kk,
    background_kk,
)

# ## Inspect the parameter metadata
#
# `BuildConstructors` keeps the starting values, bounds, and uncertainties in
# the descriptor tree. These accessors are useful before any fitting machinery
# is involved.

parameter_values(full_model_constructor)
parameter_lower_boundaries(full_model_constructor)
parameter_upper_boundaries(full_model_constructor)
parameter_uncertainties(full_model_constructor)

# ## Build and evaluate the model
#
# `build_model` turns the descriptor tree into an ordinary distribution object.

pars = parameter_values(full_model_constructor)
model = build_model(full_model_constructor, pars)

first_event = first(data2d)
model(first_event)
log(model(first_event))
extended_negative_log_likelihood(model, data2d)
extended_negative_log_likelihood(full_model_constructor, pars, data2d)

# ## Plot the model and projections
#
# `ExtendedMixtureModel` is callable: `model(x)` returns the extended density,
# whose integral over the support is the total expected yield. The 2D heatmap
# shows the starting model in 2D; `histogram2d` displays the data in the same
# plane. The one-dimensional histograms compare each marginal to the model
# projection.

gr()
theme(:boxed)

mass_grid = collect(range(KK_LIMITS[1], KK_LIMITS[2]; length = 160))
density_grid = [model([m1, m2]) for m1 in mass_grid, m2 in mass_grid]

marginal_1 = DistributionsHEP.marginalize(model, 1)
marginal_2 = DistributionsHEP.marginalize(model, 2)
projection_1 = marginal_1.(mass_grid)
projection_2 = marginal_2.(mass_grid)

bin_scale = (KK_LIMITS[2] - KK_LIMITS[1]) / 60

p_model = heatmap(
    mass_grid,
    mass_grid,
    density_grid;
    xlabel = "m(K⁺K⁻)₁ [GeV]",
    ylabel = "m(K⁺K⁻)₂ [GeV]",
    title = "Starting 2D extended model",
    colorbar_title = "extended density",
    color = :viridis,
)

p_data = histogram2d(
    fit_df.mKK1,
    fit_df.mKK2;
    bins = (60, 60),
    xlabel = "m(K⁺K⁻)₁ [GeV]",
    ylabel = "m(K⁺K⁻)₂ [GeV]",
    title = "Data",
    color = :blues,
)

p_m1 = histogram(
    fit_df.mKK1;
    bins = 60,
    fillcolor = :steelblue,
    fillalpha = 0.45,
    linecolor = :steelblue,
    linewidth = 0.5,
    xlabel = "m(K⁺K⁻)₁ [GeV]",
    ylabel = "events / bin",
    title = "m(K⁺K⁻)₁ projection",
)
plot!(p_m1, mass_grid, projection_1 .* bin_scale; color = :black)

p_m2 = histogram(
    fit_df.mKK2;
    bins = 60,
    fillcolor = :darkorange,
    fillalpha = 0.45,
    linecolor = :darkorange,
    linewidth = 0.5,
    xlabel = "m(K⁺K⁻)₂ [GeV]",
    ylabel = "events / bin",
    title = "m(K⁺K⁻)₂ projection",
)
plot!(p_m2, mass_grid, projection_2 .* bin_scale; color = :black)

plot(
    p_model,
    p_data,
    p_m1,
    p_m2;
    layout = (2, 2),
    size = (900, 760),
    link = :none,
)
