# 2D fit minimizer survey

Generated: 2026-05-19 17:29:06

| rank | stage | method | status | best NLL | ΔNLL | calls | sec | edm |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | all_free | Minuit2.Migrad(strategy=1) | ok | -2959.867563 | 0.0 | 303 | 0.393 | 0.0 |
| 2 | all_free | Optim.Fminbox(LBFGS(); Minuit metric) | budget | -2959.821478 | 0.046086 | 501 | 0.943 |  |
| 3 | all_free | Optim.Fminbox(BFGS(); Minuit metric) | budget | -2959.812389 | 0.055174 | 501 | 1.026 |  |
| 4 | all_free | Minuit2.Migrad(strategy=2) | ok | -2959.481634 | 0.385929 | 427 | 0.137 | 0.0 |
| 5 | all_free | Optim.Fminbox(BFGS()) | budget | -2959.038421 | 0.829143 | 501 | 1.457 |  |
| 6 | all_free | Optim.Fminbox(LBFGS(); descriptor steps) | budget | -2957.171588 | 2.695976 | 501 | 0.199 |  |
| 7 | all_free | Optim.Fminbox(LBFGS()) | budget | -2954.723087 | 5.144476 | 501 | 2.462 |  |
| 8 | mass_only | Optim.Fminbox(BFGS()) | ok | -2933.364754 | 26.50281 | 298 | 0.999 |  |
| 9 | mass_only | Optim.Fminbox(LBFGS()) | ok | -2933.364754 | 26.50281 | 361 | 2.384 |  |
| 10 | mass_only | Minuit2.Migrad(strategy=1) | ok | -2933.364754 | 26.50281 | 18 | 0.203 | 0.0 |
| 11 | mass_only | Minuit2.Migrad(strategy=2) | ok | -2933.364754 | 26.50281 | 30 | 0.019 | 0.0 |
| 12 | mass_only | Optim.Fminbox(LBFGS(); descriptor steps) | ok | -2933.364754 | 26.50281 | 200 | 0.116 |  |
| 13 | mass_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2933.364753 | 26.502811 | 20 | 0.712 | 1.0e-6 |
| 14 | mass_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2933.364753 | 26.502811 | 20 | 0.614 | 0.0 |
| 15 | yield_only | Optim.Fminbox(LBFGS()) | ok | -2923.404898 | 36.462666 | 414 | 3.412 |  |
| 16 | yield_only | Optim.Fminbox(BFGS()) | ok | -2923.404898 | 36.462666 | 463 | 1.061 |  |
| 17 | yield_only | Minuit2.Migrad(strategy=2) | ok | -2923.404898 | 36.462666 | 176 | 0.087 | 0.0 |
| 18 | yield_only | Minuit2.Migrad(strategy=1) | ok | -2923.404898 | 36.462666 | 82 | 0.824 | 0.0 |
| 19 | yield_only | Optim.Fminbox(LBFGS(); Minuit metric) | budget | -2923.401196 | 36.466368 | 501 | 0.829 |  |
| 20 | yield_only | Optim.Fminbox(BFGS(); Minuit metric) | budget | -2923.401182 | 36.466382 | 501 | 0.923 |  |
| 21 | yield_only | Optim.Fminbox(LBFGS(); descriptor steps) | budget | -2923.398319 | 36.469244 | 501 | 0.762 |  |
| 22 | yield_only | Optim.NelderMead() | no | -2923.350201 | 36.517362 | 50 | 0.559 |  |
| 23 | all_free | Optim.NelderMead() | no | -2912.133943 | 47.73362 | 213 | 0.661 |  |
| 24 | shape_only | Minuit2.Migrad(strategy=1) | ok | -2910.634352 | 49.233212 | 195 | 0.272 | 2.0e-6 |
| 25 | shape_only | Minuit2.Migrad(strategy=2) | ok | -2910.63435 | 49.233214 | 261 | 0.069 | 2.0e-6 |
| 26 | shape_only | Optim.Fminbox(BFGS()) | budget | -2910.634329 | 49.233234 | 501 | 1.172 |  |
| 27 | shape_only | Optim.Fminbox(LBFGS()) | budget | -2910.634323 | 49.233241 | 501 | 3.096 |  |
| 28 | shape_only | Optim.Fminbox(LBFGS(); descriptor steps) | budget | -2910.633905 | 49.233658 | 501 | 0.296 |  |
| 29 | shape_only | Optim.Fminbox(BFGS(); Minuit metric) | budget | -2910.621841 | 49.245723 | 501 | 1.187 |  |
| 30 | shape_only | Optim.Fminbox(LBFGS(); Minuit metric) | budget | -2910.621809 | 49.245755 | 501 | 0.731 |  |
| 31 | shape_only | Optim.NelderMead() | error | -2904.271919 | 55.595644 | 5 | 0.395 |  |
| 32 | yield_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.415 |  |
| 33 | mass_only | Optim.NelderMead() | ok | -2904.091787 | 55.775776 | 6 | 0.422 |  |
| 34 | mass_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.257 |  |
| 35 | shape_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.266 |  |
| 36 | all_free | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.259 |  |

Status: `ok` converged, `budget` hit the configured computation budget, `error` threw before convergence, `no` stopped without convergence.
