# 2D distribution fit minimizer study

This example reproduces the two-dimensional `mKK1` vs `mKK2` extended-likelihood
fit imported from:

`X2VV.jl/analyses/ccbar2phiphi_fromb/3d_binned_dataframe/03_fit_2d.jl`

The objective is to make a small, versioned benchmark for systematic studies of
the minimizer landscape with `BuildConstructors.jl` model constructors and
`ComponentArrays.jl` parameter vectors. This is a research project: the output
should be better documentation and clearer guidance about how to formulate,
diagnose, and solve constrained likelihood optimization problems.

The physics model has three extended-yield components:

- `phi phi`: signal shape in both `mKK` axes
- `mixed`: signal shape in one axis and combinatorial background in the other
- `kkkk`: combinatorial background in both axes

The main questions for this study are:

- Compare a list of `Optim.jl` minimizers with their default settings.
- Compare `Optim.LBFGS()` / `Optim.BFGS()` with accurate configuration:
  starting step sizes, finite-difference scales, and parameter bounds.
- Tune `Optim.Fminbox(LBFGS())` and `Optim.Fminbox(BFGS())` against the Minuit
  reference by matching descriptor step sizes, initial inverse-Hessian scale,
  and EDM-style stopping where Optim exposes the needed state.
- Compare low-level `Minuit2.jl` with explicit parameter limits and
  descriptor-derived step sizes. The `Optimization.jl` interface is useful for
  ecosystem compatibility, but the current Minuit2 extension does not forward
  per-parameter `error` / step-size information.

The known failure modes are:

- The extended NLL can be evaluated at invalid points such as negative yields.
  This needs bounds and sensible step sizes.
- Releasing every parameter at once can make the extended fit very slow. The
  preferred study strategy is staged `fix!` / `release!` sequences.
- Some derivative-free defaults, notably `NelderMead()`, can get stuck at the
  initial point for this model.

## Files

- `data/fit_events.arrow`: copied input table with the fitted event sample.
- `src/two_dimensional_fit.jl`: data loading, constructors, likelihood, and
  optimizer helpers.
- `src/minimizer_survey.jl`: tiny module entry point for the survey tools.
- `src/survey_core.jl`: shared budget, stage, scoreboard, and CSV/Markdown
  mechanics.
- `src/optim_support.jl`: shared Optim preconditioners and EDM-style
  callbacks.
- `src/optim_runners.jl`: Optim-specific runners and tuned Optim settings.
- `src/Minuit2CAInterface.jl`: compact reusable Minuit2 wrapper for
  `ComponentArray` starts, named `ComponentArray` minimizers, bounds, Minuit
  errors / steps, Migrad settings, and optional Hesse.
- `src/minuit2_runner.jl`: native Minuit2 runner using limits and descriptor
  step sizes.
- `src/method_specs.jl`: named benchmark cases. Add new minimizer
  configurations here once the runner exists.
- `03_fit_2d.jl`: runnable reproduction script with the current staged strategy.
- `04_minimizer_survey.jl`: small command-line survey runner that writes CSV and
  Markdown results under `results/`.
- `05_yield_only_minuit.jl`: focused yield-only reference fit with native
  `Minuit2.Migrad(strategy=1)`, explicit limits, and descriptor step sizes.
- `06_yield_only_optim_bfgs.jl`: the same yield-only fit with
  `Optim.Fminbox(BFGS())`, Optim/NLSolversBase finite differences,
  descriptor-scale initial inverse Hessian, and an EDM-style callback.
- `07_yield_only_optim_lbfgs.jl`: the same yield-only fit with
  `Optim.Fminbox(LBFGS())`, Optim/NLSolversBase finite differences,
  descriptor-scale diagonal preconditioner, and the same budgeted stopping
  style.
- `HANDOVER.md`: research notes, current observations, and follow-up plan.

## Running

From the repository root:

```bash
julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/03_fit_2d.jl
```

The first goal is not to declare a final optimizer, but to keep the model,
dataset, and fit strategy stable while minimizer configurations are varied.

Run a small minimizer survey:

```bash
FIT2D_SAMPLE_SIZE=250 FIT2D_MAXITERS=25 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/04_minimizer_survey.jl
```

Survey attempts are budgeted by iterations, objective calls, and wall-clock time.
Use `FIT2D_MAX_CALLS` and `FIT2D_MAX_SECONDS` to tighten or relax that budget.
The CSV scoreboard appends by default; set `FIT2D_APPEND=false` to rewrite it.

Run the focused yield-only comparison:

```bash
FIT2D_SAMPLE_SIZE=250 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/05_yield_only_minuit.jl
FIT2D_SAMPLE_SIZE=250 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/06_yield_only_optim_bfgs.jl
FIT2D_SAMPLE_SIZE=250 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/07_yield_only_optim_lbfgs.jl
```
