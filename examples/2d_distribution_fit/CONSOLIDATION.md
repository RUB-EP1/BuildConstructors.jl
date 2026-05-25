# Consolidation plan for the 2D fit tutorials

This branch is the research source of truth for the 2D minimizer study. It
contains more code than should be merged at once. The merged documentation should
arrive as small conceptual PRs that preserve the scientific workflow while
making each review narrow and complete.

The current rule is: extract from this branch, but do not dismantle this branch
until the smaller PRs have landed. It carries useful benchmark history,
scoreboards, and failed attempts that are not all appropriate for the first
documentation PRs.

## Overall shape

The first merge sequence should contain three tutorial-level PRs:

1. 2D model construction.
2. 2D minimization with Minuit2.
3. 2D minimization with Optim.

ReverseDiff, the broad minimizer survey, default optimizer zoo, scoreboards, and
research handover notes should wait. They are valuable, but they make the first
review too broad.

Every extracted PR should be complete and runnable on its own. It should also
label local code that is expected to move upstream later.

## PR 1: model construction

Goal: teach how to build the 2D model from `BuildConstructors` descriptors.

This PR should not be a minimizer PR. It should show model construction,
metadata collection, data loading, and model/projection plotting.

Recommended files:

- `examples/2d_distribution_fit/data/fit_events.arrow`
- `examples/2d_distribution_fit/src/two_dimensional_model.jl`
- `examples/2d_distribution_fit/src/extended_mixture_model.jl`
- one Literate tutorial, for example
  `docs/literate/tutorials/2d-model-construction.jl`
- generated documentation page

`src/two_dimensional_model.jl` should not define a module. It should contain
definitions only:

- package imports needed by the definitions;
- `KK_LIMITS`, `PHI_MASS_GEV`, and other model constants;
- `include("extended_mixture_model.jl")`;
- the local `DistributionsHEP` compatibility shim if still needed;
- `@with_parameters Fit2DTruncatedCrystalBall`;
- `@with_parameters Fit2DTruncatedExponential`;
- `@with_parameters Fit2DExtendedKKComponents`;
- `extended_negative_log_likelihood`.

Do not include in PR 1:

- `module TwoDimensionalFitExample`;
- `load_fit_data`;
- `build_2d_constructor`;
- `fitting_problem`;
- Minuit/Optim setup;
- survey structs;
- scoreboards;
- optimizer tests.

The tutorial should own the concrete workflow. Keep it explicit and readable:

```julia
include("src/two_dimensional_model.jl")

fit_df = DataFrame(Arrow.Table("data/fit_events.arrow"); copycols = true)
transform!(fit_df, :mKK1 => ByRow(x -> x / 1e3) => :mKK1)
transform!(fit_df, :mKK2 => ByRow(x -> x / 1e3) => :mKK2)
subset!(fit_df, :mKK1 => x -> KK_LIMITS[1] .< x .< KK_LIMITS[2])
subset!(fit_df, :mKK2 => x -> KK_LIMITS[1] .< x .< KK_LIMITS[2])
data2d = collect.(zip(fit_df.mKK1, fit_df.mKK2))
```

Then construct the model in visible blocks:

- signal `ConstructorOfFit2DTruncatedCrystalBall`;
- background `ConstructorOfFit2DTruncatedExponential`;
- full `ConstructorOfFit2DExtendedKKComponents`;
- `parameter_values`, `parameter_lower_boundaries`,
  `parameter_upper_boundaries`, and `parameter_uncertainties`;
- `build_model`;
- `pdf`, `logpdf`, and extended NLL evaluation;
- plots/projections of the model and data.

Minimal tests are not required for PR 1. The tutorial itself should be the
artifact: model creation, data loading, and plotting.

Temporary/upstream-bound code must be explicit. In particular,
`extended_mixture_model.jl` is generic distribution functionality and should
eventually move to `DistributionsHEP.jl`. Keep it in a separate file now so the
future deletion is clean.

## PR 2: minimization with Minuit2

Depends on PR 1.

Goal: demonstrate the preferred Minuit2 workflow on the 2D model.

The Minuit tutorial/script should include the model definitions and recreate the
constructor in the script:

```julia
include("src/two_dimensional_model.jl")
```

Do not hide construction behind `build_2d_constructor`. The constructor blocks
should be repeated so the tutorial stays readable and matches real usage.

The tutorial should show:

- inline data loading;
- explicit constructor creation;
- `fix!` / `release!` for the fitted subset;
- selecting released parameters with `running_names`;
- projecting `parameter_values`, boundaries, and uncertainties to a
  `ComponentArray`;
- the NLL objective;
- direct Minuit2 setup or the compact `Minuit2CAInterface`;
- `limits`, `error`/step sizes, `errordef`, `strategy`;
- access to the original Minuit object;
- optional `hesse!`.

Local interface code that should move upstream later must be labeled. The
current missing piece in the generic ecosystem is the ability to expose full
Minuit configuration through the `Optimization.jl` interface, especially
per-parameter errors/steps and post-fit diagnostics.

## PR 3: minimization with Optim

Depends on PR 1. It may refer to PR 2 conceptually, but should not depend on
Minuit wrapper internals.

Goal: demonstrate how to configure Optim fairly with the same scale information
given to Minuit.

The Optim tutorial/script should again include definitions and build the
constructor explicitly in the script. It should show:

- inline data loading;
- explicit constructor creation;
- `fix!` / `release!`;
- released-parameter projection with `running_names`;
- `Fminbox(BFGS())` with descriptor-scale initial inverse Hessian;
- `Fminbox(LBFGS())` with descriptor-scale preconditioning;
- Optim internal finite differences;
- an EDM-style stopping explanation where the Optim trace exposes enough state.

Do not include in PR 3:

- ReverseDiff;
- broad minimizer surveys;
- default optimizer zoo;
- scoreboard infrastructure.

The key documentation point is that `AdvancedParameter.uncertainty` is a metric
or step scale. It is not a finite-difference epsilon.

## Postponed work

Move these into later PRs or a different location:

- ReverseDiff and AD backend comparison;
- `DistributionsHEP` AD compatibility discussion beyond a short note;
- full minimizer survey harness;
- `MethodSpec` / `StageSpec` scoreboards;
- default optimizer survey;
- long handover notes and research score tables.

These pieces are important for the broader minimizer-landscape project, but they
should not block the first model/Minuit/Optim tutorials.

## Agent guidance

When using a separate chat/agent, give it exactly one PR target.

For PR 1:

> Extract only the 2D model construction tutorial and importable model-definition
> file from the research branch. Do not create a module. Do not add minimizer
> machinery. Keep data loading and model construction explicit in the Literate
> tutorial. Keep upstream-bound code in separate files and label it.

For PR 2:

> Starting from PR 1, add the Minuit2 fitting tutorial. Reconstruct the model in
> the tutorial. Show released-parameter projection, bounds, steps/errors,
> `errordef`, strategy, `migrad!`, and access to the Minuit object. Do not add
> Optim or survey code.

For PR 3:

> Starting from PR 1, add the Optim fitting tutorial. Reconstruct the model in
> the tutorial. Show BFGS/LBFGS tuned with descriptor scale and Optim internal
> finite differences. Do not add ReverseDiff or scoreboards.

The smaller PRs should leave this research branch intact until its findings are
fully harvested.
