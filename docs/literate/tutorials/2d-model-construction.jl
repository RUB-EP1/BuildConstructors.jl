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
# `AdvancedParameter` values carry the initial value, fit boundaries, and a
# scale estimate. `Fixed` marks a value as metadata-free configuration for the
# current model.

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
# The full model has three yield components: signal/signal, mixed
# signal/background, and background/background.

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
