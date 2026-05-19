# 2D fit minimizer survey

Generated: 2026-05-16 21:25:55

| stage | method | bounded | events | maxiters | calls | max calls | max seconds | converged | iterations | seconds | budget | errored |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| yield_only | Optim.Fminbox(LBFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 7.262 | true | true |
| yield_only | Optim.Fminbox(BFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 6.313 | true | true |
| yield_only | Optim.NelderMead() | false | 10090 | 50 | 94 | 600 | 30.000 | false | 50 | 1.360 | false | false |
| yield_only | Optim.ParticleSwarm() | false | 10090 | 50 | 2 | 600 | 30.000 | false |  | 0.377 | false | true |
| mass_only | Optim.Fminbox(LBFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 7.127 | true | true |
| mass_only | Optim.Fminbox(BFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 6.340 | true | true |
| mass_only | Optim.NelderMead() | false | 10090 | 50 | 6 | 600 | 30.000 | true | 1 | 0.444 | false | false |
| mass_only | Optim.ParticleSwarm() | false | 10090 | 50 | 2 | 600 | 30.000 | false |  | 0.236 | false | true |
| shape_only | Optim.Fminbox(LBFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 6.892 | true | true |
| shape_only | Optim.Fminbox(BFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 6.384 | true | true |
| shape_only | Optim.NelderMead() | false | 10090 | 50 | 5 | 600 | 30.000 | false |  | 0.503 | false | true |
| shape_only | Optim.ParticleSwarm() | false | 10090 | 50 | 2 | 600 | 30.000 | false |  | 0.244 | false | true |
| all_free | Optim.Fminbox(LBFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 7.031 | true | true |
| all_free | Optim.Fminbox(BFGS()) | true | 10090 | 50 | 601 | 600 | 30.000 | false |  | 6.320 | true | true |
| all_free | Optim.NelderMead() | false | 10090 | 50 | 259 | 600 | 30.000 | false | 50 | 2.783 | false | false |
| all_free | Optim.ParticleSwarm() | false | 10090 | 50 | 2 | 600 | 30.000 | false |  | 0.316 | false | true |
