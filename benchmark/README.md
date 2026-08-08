# Benchmarks

Measure runtime and memory overhead of BuildConstructors relative to hand-written model construction.

```bash
julia --project=. -e 'using Pkg; Pkg.develop(path=".."); Pkg.instantiate()'
julia --project=. runbenchmarks.jl
```

See [OVERHEAD.md](OVERHEAD.md) for interpreted results and guidance for fitting workflows.
