# 2D fit minimizer survey

Generated: 2026-05-20 10:39:35

| rank | stage | method | status | best NLL | ΔNLL | calls | sec | edm |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | all_free | Minuit2.Migrad(strategy=1) | ok | -2959.867563 | 0.0 | 303 | 0.402 | 0.0 |
| 2 | all_free | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2959.863994 | 0.003569 | 391 | 0.822 | 4.0e-6 |
| 3 | all_free | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2959.863974 | 0.003589 | 361 | 0.771 | 2.0e-6 |
| 4 | all_free | Minuit2.Migrad(strategy=2) | error | -2959.481635 | 0.385929 | 375 | 0.097 |  |
| 5 | all_free | Optim.Fminbox(BFGS()) | budget | -2959.038421 | 0.829143 | 501 | 0.942 |  |
| 6 | all_free | Optim.Fminbox(LBFGS()) | budget | -2954.723087 | 5.144476 | 501 | 2.395 |  |
| 7 | mass_only | Optim.Fminbox(BFGS()) | ok | -2933.364754 | 26.50281 | 298 | 1.161 |  |
| 8 | mass_only | Optim.Fminbox(LBFGS()) | ok | -2933.364754 | 26.50281 | 361 | 2.742 |  |
| 9 | mass_only | Minuit2.Migrad(strategy=1) | ok | -2933.364754 | 26.50281 | 18 | 0.181 | 0.0 |
| 10 | mass_only | Minuit2.Migrad(strategy=2) | error | -2933.364754 | 26.50281 | 25 | 0.015 |  |
| 11 | mass_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2933.364752 | 26.502811 | 16 | 0.673 | 1.0e-6 |
| 12 | mass_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2933.364752 | 26.502811 | 16 | 0.617 | 0.0 |
| 13 | yield_only | Optim.Fminbox(LBFGS()) | ok | -2923.404898 | 36.462666 | 414 | 3.191 |  |
| 14 | yield_only | Optim.Fminbox(BFGS()) | ok | -2923.404898 | 36.462666 | 463 | 1.136 |  |
| 15 | yield_only | Minuit2.Migrad(strategy=2) | error | -2923.404898 | 36.462666 | 160 | 0.960 |  |
| 16 | yield_only | Minuit2.Migrad(strategy=1) | ok | -2923.404898 | 36.462666 | 82 | 0.782 | 0.0 |
| 17 | yield_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2923.404892 | 36.462672 | 57 | 0.726 | 3.0e-6 |
| 18 | yield_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2923.404892 | 36.462672 | 57 | 0.686 | 3.0e-6 |
| 19 | yield_only | Optim.NelderMead() | no | -2923.350201 | 36.517362 | 50 | 0.493 |  |
| 20 | all_free | Optim.NelderMead() | no | -2912.133943 | 47.73362 | 213 | 0.485 |  |
| 21 | shape_only | Minuit2.Migrad(strategy=2) | error | -2910.634352 | 49.233211 | 235 | 0.068 |  |
| 22 | shape_only | Minuit2.Migrad(strategy=1) | ok | -2910.634352 | 49.233212 | 195 | 0.219 | 2.0e-6 |
| 23 | shape_only | Optim.Fminbox(BFGS()) | budget | -2910.634329 | 49.233234 | 501 | 0.943 |  |
| 24 | shape_only | Optim.Fminbox(LBFGS()) | budget | -2910.634323 | 49.233241 | 501 | 2.089 |  |
| 25 | shape_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2910.621827 | 49.245736 | 113 | 0.717 | 2.0e-6 |
| 26 | shape_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2910.604326 | 49.263237 | 78 | 0.669 | 7.0e-6 |
| 27 | shape_only | Optim.NelderMead() | error | -2904.271919 | 55.595644 | 5 | 0.373 |  |
| 28 | yield_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.372 |  |
| 29 | mass_only | Optim.NelderMead() | ok | -2904.091787 | 55.775776 | 6 | 0.373 |  |
| 30 | mass_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.225 |  |
| 31 | shape_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.248 |  |
| 32 | all_free | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.234 |  |

Status: `ok` converged, `budget` hit the configured computation budget, `error` threw before convergence, `no` stopped without convergence.
