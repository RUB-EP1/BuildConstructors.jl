# BuildConstructors overhead

Fit metadata lives in a constructor tree; each optimizer step calls `build_model(constructor, pars)`. Extra work is confined to that call (not PDF evaluation). Measured on Julia 1.11.5, BuildConstructors 0.7.0 (Apple Silicon, Aug 2026).

## Where it comes from

1. **Parameter lookup** — `::P` fields become `value(descriptor; pars)`; running params use `getproperty(pars, Symbol(name))`, `Fixed` reads a stored constant. With `NamedTuple` this is usually cheap after inlining, but adds dispatch + `Symbol(name)` vs hand-written `pars.μ`.
2. **Nested `build_model`** — the same `pars` is passed by reference to every child; each node pays dynamic dispatch and re-resolves its own descriptors. Fixed subtrees still re-run their build bodies each iteration.
3. **Not in the hot path** — `validate_parameters` (once at construction), metadata collectors, serialization. Built-model allocations (`Normal`, FFT grids, …) dominate and match hand-written cost.

## Verdict

| | |
| --- | --- |
| **Fit loop** | ~**9%** on a full PRB model (build + 1000× likelihood); ~**0.7 μs** extra on ~4.4 μs `build_model`. Simple models: ~2–3× on a sub-ns path — irrelevant next to NLL. |
| **Metadata API** | Sub-ns; call at setup only, not in `objective`. |
| **Memory** | Constructor tree ~**150–400 B**; built physics models ~**300 KiB** (grids). |

Likelihood evaluation dominates typical fits. Overhead matters only for trivial objectives or very deep trees where `build_model` rivals evaluation cost.

## Results

`build_model` vs hand-written baseline; fit step = build + likelihood on 1000 points.

| Model | build (BC / baseline) | fit step ratio | constructor |
| --- | --- | --- | --- |
| Gaussian (2 p) | ~0 / ~0 ns (2.6×) | 1.06× | 148 B |
| Nested mixture (5 p) | ~0 / ~0 ns (2.6×) | — | 388 B |
| PRB physics (1 running) | 5.1 / 4.4 μs (1.17×) | 1.09× | 177 B |
| PRB from JSON (6 running) | 4.5 μs | — | 236 B |

PRB case: Breit–Wigner + CrystalBall/sech + Chebyshev + FFT (`grid_size = 10_000`). Leaf construction dominates; descriptor cost is a small fraction.

## Reproduce

```bash
cd benchmark
julia --project=. -e 'using Pkg; Pkg.develop(path=".."); Pkg.instantiate()'
julia --project=. runbenchmarks.jl
```
