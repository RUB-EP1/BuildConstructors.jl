# 2D Model Construction

This tutorial builds a two-dimensional extended mass model directly from
`BuildConstructors` descriptors. It stops at model construction, data loading,
metadata inspection, and plotting; minimizer setup belongs in separate
tutorials.

The example uses two small local support files:

- `src/two_dimensional_model.jl` defines only constructor types, constants,
  compatibility shims, and the extended negative log-likelihood.
- `src/extended_mixture_model.jl` contains generic extended-mixture
  distribution functionality. It is kept separate because it should migrate to
  `DistributionsHEP.jl` or another shared distribution package later.

````julia
using Arrow
using BuildConstructors
using CairoMakie
using DataFrames
using Distributions

example_dir = joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit")
model_source = joinpath(example_dir, "src", "two_dimensional_model.jl")

include(model_source)
````

## Load the data

The Arrow fixture stores the two K+K- masses in MeV. The model constants are
in GeV, so the conversion and the fit-window cuts are intentionally visible
here instead of hidden behind a helper function.

````julia
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
````

## Build the one-dimensional components

`AdvancedParameter` values carry the initial value, fit boundaries, and a
scale estimate. `Fixed` marks a value as metadata-free configuration for the
current model.

````julia
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
````

## Assemble the extended 2D model

The full model has three yield components: signal/signal, mixed
signal/background, and background/background.

````julia
full_model_constructor = ConstructorOfFit2DExtendedKKComponents(
    signal_kk,
    background_kk,
    AdvancedParameter("y_phiphi", 0.3 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_mixed", 0.1 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_kkkk", 0.6 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
)
````

## Inspect the parameter metadata

`BuildConstructors` keeps the starting values, bounds, and uncertainties in
the descriptor tree. These accessors are useful before any fitting machinery
is involved.

````julia
parameter_values(full_model_constructor)
parameter_lower_boundaries(full_model_constructor)
parameter_upper_boundaries(full_model_constructor)
parameter_uncertainties(full_model_constructor)
````

## Build and evaluate the model

`build_model` turns the descriptor tree into an ordinary distribution object.

````julia
pars = parameter_values(full_model_constructor)
model = build_model(full_model_constructor, pars)

first_event = first(data2d)
pdf(model, first_event)
logpdf(model, first_event)
extended_negative_log_likelihood(model, data2d)
extended_negative_log_likelihood(full_model_constructor, pars, data2d)
````

## Plot the model and projections

The density returned by `pdf(model, x)` is an extended density, so its
integral over the model support is the total expected yield. The 2D heatmap
and the two one-dimensional projections below are diagnostic views of the
starting model, not fitted results.

````julia
mass_grid = range(KK_LIMITS[1], KK_LIMITS[2]; length = 160)
density_grid = [pdf(model, [m1, m2]) for m1 in mass_grid, m2 in mass_grid]

fig = Figure(size = (900, 760))
ax = Axis(
    fig[1, 1],
    xlabel = "m(K^{+}K^{-})_{1} [GeV]",
    ylabel = "m(K^{+}K^{-})_{2} [GeV]",
    title = "Starting 2D extended model",
)
hm = heatmap!(ax, mass_grid, mass_grid, density_grid)
scatter!(ax, fit_df.mKK1, fit_df.mKK2; markersize = 2, color = (:white, 0.35))
Colorbar(fig[1, 2], hm, label = "extended density")

step = (last(mass_grid) - first(mass_grid)) / (length(mass_grid) - 1)
marginal_1 = marginalize(model, 1)
marginal_2 = marginalize(model, 2)
projection_1 = pdf.(Ref(marginal_1), mass_grid)
projection_2 = pdf.(Ref(marginal_2), mass_grid)

ax1 = Axis(fig[2, 1], xlabel = "m(K^{+}K^{-})_{1} [GeV]", ylabel = "events / bin")
hist!(ax1, fit_df.mKK1; bins = 60, color = (:steelblue, 0.35), strokewidth = 0)
lines!(ax1, mass_grid, projection_1 .* (KK_LIMITS[2] - KK_LIMITS[1]) / 60; color = :black, linewidth = 2)

ax2 = Axis(fig[3, 1], xlabel = "m(K^{+}K^{-})_{2} [GeV]", ylabel = "events / bin")
hist!(ax2, fit_df.mKK2; bins = 60, color = (:darkorange, 0.35), strokewidth = 0)
lines!(ax2, mass_grid, projection_2 .* (KK_LIMITS[2] - KK_LIMITS[1]) / 60; color = :black, linewidth = 2)

fig
````

