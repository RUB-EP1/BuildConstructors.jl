# BuildConstructors overhead

BuildConstructors keeps fit metadata (names, bounds, fixed/free state) in a **constructor tree** and builds the domain model on demand via `build_model(constructor, pars)`. The question for fitting is: how much does that indirection cost at runtime and in memory?

## Short answer

| Concern | Verdict |
| --- | --- |
| **Fit-loop runtime** | Negligible for realistic models. On a full PRB physics model, one likelihood evaluation is **~9% slower** than hand-written construction; the extra `build_model` work is **~0.7 μs** on a **~4.4 μs** baseline. |
| **Simple models** | `build_model` can be **~2–3× slower** than direct construction, but absolute time is **sub-nanosecond** per call — far below PDF/NLL cost. |
| **Metadata API** | **`running_*` / `parameter_*` collectors are ~0.1–0.4 ns** per call. Use them at setup time, not inside the optimizer loop. |
| **Memory** | The constructor tree is **~150–400 bytes** for the cases below. Built physics models are **~300 KiB** (FFT grids, interpolated PDFs). The package adds **no significant persistent memory** beyond the descriptor tree. |

## How to reproduce

```bash
cd benchmark
julia --project=. -e 'using Pkg; Pkg.develop(path=".."); Pkg.instantiate()'
julia --project=. runbenchmarks.jl
```

Environment: Julia **1.11.5**, BuildConstructors **0.7.0**, Apple Silicon (aarch64), August 2026.

## What is measured

### 1. `build_model` vs hand-written baseline

Each row compares `build_model(constructor, pars)` against equivalent code that reads `pars` directly and constructs the same object (no descriptors, no recursion).

| Model | BuildConstructors | Baseline | Ratio |
| --- | --- | --- | --- |
| Gaussian (2 params) | ~0 ns | ~0 ns | 2.6× |
| Nested mixture (5 params) | ~0 ns | ~0 ns | 2.6× |
| PRB physics (1 running param) | 5.1 μs | 4.4 μs | 1.17× |
| PRB from JSON (6 running params) | 4.5 μs | — | — |

The PRB model includes Breit–Wigner integration, CrystalBall+sech resolution, Chebyshev background, and an FFT convolution (`grid_size = 10_000`). That dominates build time; descriptor lookup is a small fraction.

### 2. One fit-iteration surrogate

Simulates what an optimizer sees each step: **build model + evaluate likelihood on 1000 points**.

| Model | BuildConstructors | Baseline | Ratio |
| --- | --- | --- | --- |
| Gaussian | ~0.1 ns | ~0.1 ns | 1.06× |
| PRB physics | 4.7 μs | 4.3 μs | 1.09× |

Once PDF evaluation is included, BuildConstructors overhead **shrinks to noise for simple models** and **~9% for heavy physics models**. In typical fits with thousands of events and many optimizer iterations, **likelihood evaluation dominates**; `build_model` is not the bottleneck.

### 3. Metadata collectors (setup only)

| Model | `running_values` | `running_names` | `parameter_metadata` |
| --- | --- | --- | --- |
| Gaussian | 0.1 ns | 0.0 ns | 0.0 ns |
| Nested mixture | 0.3 ns | 0.2 ns | 0.1 ns |
| PRB physics | 0.1 ns | 0.1 ns | 0.1 ns |
| PRB from JSON | 0.3 ns | 0.3 ns | 0.2 ns |

Call these **once** when setting up bounds, starting values, and fit vectors — not inside `objective(pars)`.

### 4. Memory (`Base.summarysize`)

| Model | Constructor | Built model | Notes |
| --- | --- | --- | --- |
| Gaussian | 148 B | 72 B | Constructor holds parameter descriptors + support tuple |
| Nested mixture | 388 B | 264 B | Tree of nested constructors |
| PRB physics | 177 B | 329 KiB | Model stores convolution grids |
| PRB from JSON | 236 B | 293 KiB | Same: heavy objects live in the built model |

The constructor is **persistent** (one per fit configuration). Built models are usually **recreated each iteration** and can be much larger; that cost exists with or without BuildConstructors.

## Recommended usage pattern

```julia
# Setup (once)
start = running_values(constructor)
lower = running_lower_boundaries(constructor)
upper = running_upper_boundaries(constructor)

# Optimizer loop (many times)
function objective(pars)
    model = build_model(constructor, pars)
    return -sum(logpdf.(Ref(model), data))
end
```

Avoid calling `running_values`, `parameter_metadata`, or `fix!` inside `objective`.

## When overhead might matter

- **Very cheap objectives** where `build_model` runs on every call but likelihood evaluation is trivial (e.g. a handful of arithmetic operations). Consider caching the built model if parameters change in structured ways, or building only the sub-tree that depends on running parameters.
- **Extremely deep constructor trees** with many nested `build_model` calls — profile if build time approaches evaluation time.

For the intended use case — nested physics PDFs, extended likelihoods, and optimizers with hundreds/thousands of evaluations — **BuildConstructors overhead is small compared to model evaluation**.
