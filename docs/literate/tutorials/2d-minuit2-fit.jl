# # 2D Minuit2 Fit
#
# This tutorial continues the 2D model construction example and fits the
# extended 2D model with `Minuit2.jl`. It keeps the same explicit workflow:
# include the model definitions, load the data in the script, build the
# constructor in visible blocks, and only then set up the minimizer.
#
# The low-level Minuit2 call goes through a small local adapter,
# `src/Minuit2CAInterface.jl`. That wrapper is kept separate because the generic
# `Optimization.jl` interface still does not expose per-parameter Minuit errors,
# fixed masks, or post-fit diagnostics such as `hesse!`.

using Arrow
using BuildConstructors
using ComponentArrays
using DataFrames
using Distributions
using DistributionsHEP

example_dir = joinpath(@__DIR__, "..", "..", "..", "examples", "2d_distribution_fit")
model_source = joinpath(example_dir, "src", "two_dimensional_model.jl")
interface_source = joinpath(example_dir, "src", "Minuit2CAInterface.jl")

include(model_source)
include(interface_source)

using .Minuit2CAInterface

# ## Load the data
#
# The data loading matches the model-construction tutorial: convert MeV to GeV,
# apply the fit-window cuts, and keep the event list in the script.

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

full_model_constructor = ConstructorOfFit2DExtendedKKComponents(
    signal_kk,
    background_kk,
    AdvancedParameter("y_phiphi", 0.3 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_mixed", 0.1 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
    AdvancedParameter("y_kkkk", 0.6 * n_events; boundaries = (0.0, n_events), uncertainty = sqrt(n_events)),
)

# ## Release the yield parameters
#
# Start from a fully fixed constructor, then release the three extended yields.
# `running_names` reports the active subset that Minuit will see.

fix!(full_model_constructor)
release!(full_model_constructor, (:y_phiphi, :y_mixed, :y_kkkk))
released = running_names(full_model_constructor)

# ## Project the released subset to `ComponentArray`s
#
# Minuit receives only the released parameters. The descriptor tree still stores
# the fixed shape parameters; `build_model` reads them from the constructor when
# the objective passes a released-only `ComponentArray`.

all_start = ComponentArray(parameter_values(full_model_constructor))
all_lower = ComponentArray(parameter_lower_boundaries(full_model_constructor))
all_upper = ComponentArray(parameter_upper_boundaries(full_model_constructor))
all_steps = ComponentArray(
    map(v -> coalesce(v, 0.1), parameter_uncertainties(full_model_constructor)),
)

start = all_start[released]
lower = all_lower[released]
upper = all_upper[released]
steps = all_steps[released]

# ## Define the negative log-likelihood objective
#
# Subtract the starting NLL so Minuit works with a small offset around zero.
# The fitted minimum is therefore a ΔNLL relative to the starting point.

base_nll = extended_negative_log_likelihood(full_model_constructor, start, data2d)
objective(pars) = extended_negative_log_likelihood(full_model_constructor, pars, data2d) - base_nll

# ## Run Minuit2 through the local adapter
#
# - `lower` / `upper` keep yields inside the physical region.
# - `errors = steps` passes descriptor uncertainties as Minuit step sizes.
# - `errordef = 0.5` is appropriate for a negative log-likelihood.
# - `strategy = 1` is the default balance between robustness and call count.

result = optimize(
    objective,
    start,
    Minuit2CA(;
        strategy = 1,
        tolerance = 0.01,
        errordef = 0.5,
        maxcalls = 500,
        errors = steps,
        lower,
        upper,
        names = released,
    ),
)

fitted = minimizer(result)
minuit = original(result)

fitted
minimum(result)
converged(result)
minuit.edm
minuit.nfcn

# ## Write the fit back into the constructor
#
# `update!` stores the fitted values in the descriptor tree. The underlying
# Minuit object remains available for follow-up calls such as `hesse!`.

BuildConstructors.update!(full_model_constructor, fitted)
parameter_values(full_model_constructor)

hesse!(result; strategy = 1, maxcalls = 100)
minuit.errors
