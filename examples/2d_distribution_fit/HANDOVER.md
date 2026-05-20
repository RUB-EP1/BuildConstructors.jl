# Hand-over notes: 2D fit minimizer landscape

This benchmark is a research fixture, not a one-off fit script.

The purpose is to understand how different minimizers behave on a realistic
extended negative log-likelihood built through `BuildConstructors.jl`, with named
`ComponentArray` parameters, physically meaningful bounds, and staged parameter
release. The result should improve documentation and give users guidance on how
to formulate and solve similar optimization problems.

## Current state

- The benchmark data lives in `data/fit_events.arrow`.
- The model and likelihood helpers live in `src/two_dimensional_fit.jl`.
- `03_fit_2d.jl` is a readable staged reproduction.
- `04_minimizer_survey.jl` is a small survey harness that writes CSV and
  Markdown summaries to `results/`.
- The survey implementation is intentionally split by concern:
  `src/survey_core.jl` owns budgets and scoreboards,
  `src/optim_runners.jl` owns Optim setups,
  `src/Minuit2CAInterface.jl` owns the reusable ComponentArray-friendly Minuit
  wrapper,
  `src/minuit2_runner.jl` owns native Minuit2 setup, and
  `src/method_specs.jl` lists named benchmark cases. Keep future minimizer
  families in separate runner files rather than growing one branchy function.
- `results/minimizer_survey.csv` is the appendable scoreboard. Add new rows for
  new strategies and minimizer configurations instead of replacing old evidence.
- Every survey attempt has a computation budget: iteration count, objective-call
  count, and wall-clock seconds. A slow minimizer should produce a recorded
  budget outcome, not an unbounded run.
- Package tests include a smoke test that verifies data loading, model building,
  finite NLL evaluation, bounded optimization, and staged release semantics.

## First observations

- The fit window currently contains `10090` events.
- The initial extended NLL is about `-154595.0446`.
- The staged `Fminbox(LBFGS())` baseline works when the optimizer vector only
  contains released parameters.
- A key bug/lesson from the first pass: `running_values(constructor)` includes
  fixed descriptors. A fit wrapper must explicitly select currently released
  parameters, otherwise inactive trial coordinates can move and then be written
  back by `update!`.
- Invalid physical regions are real, not edge cases. Negative yields or invalid
  shape parameters can make model construction fail. The benchmark objective
  converts expected `ArgumentError`s into `Inf`, so minimizers can be compared
  without crashing the whole survey.
- The full-data mass-only stage is slower per iteration than the yield-only
  stage. This is a useful target for studying finite-difference scales,
  line-search behavior, and Minuit step sizes.
- The problem should still be treated as computationally modest. If a method
  cannot make progress inside a reasonable budget, that is evidence about the
  method/configuration, not permission to run indefinitely.
- First full all-parameter result with convergence: low-level
  `Minuit2.Migrad(strategy=1)` using bounds and descriptor step sizes converged
  on the full dataset in 399 objective calls / 16 iterations with
  `best_nll = -157312.03332321078` and `edm = 3.09e-7`.
- A tuned `Optim.Fminbox(LBFGS())` comparison using the same descriptor
  finite-difference step sizes reached `best_nll = -157306.40693949876`, close
  to Minuit, but stopped on the objective-call budget. This is now a strong
  candidate for further tuning rather than a failure of the model.

## Minuit configuration notes

The current winning row uses the low-level `Minuit2.Minuit` API, not the
generic `Optimization.jl` wrapper. This is deliberate:

- The local `Minuit2CAInterface.optimize(objective, initial, Minuit2CA(...))`
  wrapper keeps the API close to `Optim.optimize` while still using native
  Minuit underneath. The objective receives a `ComponentArray`, and
  `Minuit2CAInterface.minimizer(result)` returns a `ComponentArray`.
- The native Minuit object is intentionally retained:
  `Minuit2CAInterface.original(result)` returns it for diagnostics and follow-up
  operations. `Minuit2CAInterface.hesse!(result; strategy, maxcalls)` is a
  convenience wrapper around `Minuit2.hesse!(original(result); ...)`.
- The benchmark passes `error = collect(problem.step)` to `Minuit`. These
  values come from `AdvancedParameter.uncertainty` and become Minuit's initial
  parameter errors / step scales.
- For the full fit, the current descriptor step vector is
  `(mu_B = 1e-4, sigma_B = 2e-4, alpha_B = 0.1, k_bkg_kk = 0.05,
  y_phiphi = 100.449, y_mixed = 100.449, y_kkkk = 100.449)`.
- Bounds are passed as `limits = collect(zip(problem.lower, problem.upper))`.
  This is what prevents probes into negative yields and invalid shape regions.
- The likelihood is a negative log-likelihood, so the Minuit runner sets
  `errordef = 0.5`.
- The `Minuit2.MigradOptimizer` extension for `Optimization.jl` is attractive
  because it accepts an `OptimizationProblem` whose `u0` is a `ComponentArray`,
  supports `lb` / `ub`, and returns the original `Minuit` object in
  `sol.original`. This would be the preferred interface if it exposed the full
  Minuit configuration needed by the benchmark.
- In the local package stack, `Minuit2 v0.4.2` with the currently resolved
  `Optimization.jl` does not run: `solve(prob, MigradOptimizer(...))` errors
  inside `Minuit2OptimizationExt` because it calls
  `Optimization._check_and_convert_maxiters`, which is not available in this
  `Optimization.jl` version. This should be checked again after resolving or
  updating the example environment.
- Even after that compatibility issue is fixed, the current extension
  constructs `Minuit(_loss, prob.u0; limits = ...)` without forwarding
  `error = collect(problem.step)`. That means all initial parameter errors fall
  back to Minuit2.jl default `0.1`, losing the descriptor-derived step scales
  that appear to be central to the winning native-Minuit setup.
- The current `MigradOptimizer` fields are only `strategy`, `tolerance`,
  `errordef`, and `maxfcn`. The `OptimizationProblem` supplies `u0`, `lb`, and
  `ub`; `solve(..., maxiters = n)` is mapped to the Migrad call limit. Missing
  for this benchmark are per-parameter Minuit errors / steps, fixed-parameter
  masks, native `migrad!` retry controls such as `iterate` and `use_simplex`,
  and post-fit actions such as `hesse!` / `minos!`.
- `migrad!` uses first derivatives and an approximate second-derivative
  variable-metric update. The step/error values provide the initial scale for
  numerical derivative and covariance handling; they are not a full user-supplied
  Hessian. Strategy `1` is the recommended balance, while strategy `2` spends
  more calls on reliability/accuracy checks.
- The Julia wrapper's `migrad!` calls a robust helper: it first runs Migrad with
  the requested strategy, then if the result is invalid and the call limit was
  not reached it retries with strategy `2`, optionally inserting SIMPLEX before
  another Migrad pass. The winning row converged immediately enough that this
  retry machinery was not the main story.

## Optim configuration notes

The Optim comparison should be made as close as possible to the Minuit reference
before declaring that Optim is slower or worse. The harness now keeps two tuned
Optim rows:

- `Optim.Fminbox(LBFGS(); Minuit metric)` uses a descriptor-scaled
  diagonal preconditioner. Since `Fminbox` supplies its own barrier
  preconditioner to the inner `LBFGS`, the descriptor metric is injected through
  a custom `precondprep` that combines the box-barrier Hessian with
  `1 / step^2`. Derivatives are Optim/NLSolversBase default central finite
  differences, not descriptor-scale finite differences.
- `Optim.Fminbox(BFGS(); Minuit metric)` uses Optim/NLSolversBase default
  central finite differences, a dense diagonal initial inverse Hessian with
  entries `step^2`, and an EDM-style callback.
- The focused yield-only Optim scripts use the same fair numerical-derivative
  path. An analytic yield-only gradient is possible for this reduced problem,
  but it is not representative of the all-parameter fit and should be treated as
  a separate diagnostic row if reintroduced.

The EDM callback mirrors the Minuit stopping idea:

```julia
edm = dot(g, invH * g) / 2
goal = max(2e-3 * tolerance * errordef, 4 * sqrt(eps()))
```

For `tolerance = 0.01` and `errordef = 0.5`, this gives `goal = 1e-5`, matching
the current Minuit setup. Full-memory `BFGS` exposes the approximate inverse
Hessian directly, so this is a real EDM-like quantity. `LBFGS` does not expose a
full `~inv(H)` in its trace, so the current LBFGS row uses a diagonal EDM proxy
from the descriptor metric. This distinction should remain visible in the
scoreboard notes.

New Optim cases should be added as explicit named configurations, for example
vanilla `Fminbox(LBFGS())`, descriptor preconditioning, full-memory `BFGS` with
initial inverse Hessian, alternate line searches, or alternate AD backends. The
point is to build a large collection of small readable cases that demonstrate
how setup choices change performance.

## Research axes

1. Optimizer family

   Compare bounded first-order, unbounded first-order, derivative-free, and
   Minuit-style variable metric approaches. The goal is not only convergence,
   but also diagnostics: failures, invalid probes, iteration count, wall time,
   and sensitivity to parameter scales.

2. Bounds and parameterization

   Study whether explicit bounds are enough, or whether some parameters should
   be reparameterized internally, for example positive yields through transformed
   variables. Bounds prevent many invalid points but finite-difference and
   line-search behavior near boundaries still matters.

3. Step size and scale

   `AdvancedParameter.uncertainty` should become the central source of initial
   step sizes and optimizer metrics. It should not be reused as the
   finite-difference epsilon for `Optim`; Optim/NLSolversBase already chooses
   derivative perturbations for that role.

4. Staged strategy

   Study staged `fix!` / `release!` workflows:

   - yields only
   - mass only after yield stabilization
   - shape only
   - coupled subsets
   - all free as a stress test

5. Objective evaluation cost

   The benchmark records objective-call counts and wall time. The next step is
   to record time per objective call directly, which will separate algorithm
   behavior from likelihood implementation cost.

## Suggested next experiments

1. Add objective-call counting around `fitting_problem.objective`.
2. Extend the low-level `Minuit2.Minuit` runner with staged warm starts and
   optional `simplex!` fallback before `migrad!`.
3. Add Minuit strategy rows to staged workflows, not only `all_free`, to test
   whether staged release still improves robustness and final likelihood.
4. Add one survey mode on a small deterministic subset and one on the full
   dataset. Keep the small mode in CI; keep the full mode manual.
5. Save fitted parameters as structured data, not just strings, once the result
   schema stabilizes.
6. Add plots of likelihood scans for single parameters around the current best
   point, especially `mu_B`, yields, and `k_bkg_kk`.

## Commands

Run the staged reproduction:

```sh
julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/03_fit_2d.jl
```

Run a small minimizer survey:

```sh
FIT2D_SAMPLE_SIZE=250 FIT2D_MAXITERS=25 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/04_minimizer_survey.jl
```

The survey also accepts `FIT2D_MAX_CALLS` and `FIT2D_MAX_SECONDS`:

```sh
FIT2D_SAMPLE_SIZE=250 FIT2D_MAXITERS=25 FIT2D_MAX_CALLS=500 FIT2D_MAX_SECONDS=20 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/04_minimizer_survey.jl
```

Set `FIT2D_APPEND=false` to rewrite the CSV scoreboard for a clean run.

Run a larger survey manually:

```sh
FIT2D_SAMPLE_SIZE=10090 FIT2D_MAXITERS=100 julia --project=examples/2d_distribution_fit examples/2d_distribution_fit/04_minimizer_survey.jl
```

## Documentation outcome

The intended documentation output is a practical guide:

- how to expose constructor parameters to optimizers;
- how fixed and released parameters should map to optimizer vectors;
- how to choose bounds and initial step sizes;
- when to use `Optim.Fminbox(LBFGS())`, derivative-free methods, or `Minuit2`;
- how to diagnose invalid-region probes and stalled minimizers.
