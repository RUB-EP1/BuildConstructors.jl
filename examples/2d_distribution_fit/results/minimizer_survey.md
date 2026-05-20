# 2D fit minimizer survey

Generated: 2026-05-20 10:50:25

| rank | stage | method | status | best NLL | ΔNLL | calls | sec | edm |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | all_free | Minuit2.Migrad(strategy=1) | ok | -2959.867563 | 0.0 | 303 | 0.306 | 0.0 |
| 2 | all_free | Optim.Fminbox(BFGS(); Minuit metric, ReverseDiff) | ok | -2959.863996 | 0.003568 | 25 | 0.134 | 4.0e-6 |
| 3 | all_free | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2959.863994 | 0.003569 | 391 | 0.836 | 4.0e-6 |
| 4 | all_free | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2959.863974 | 0.003589 | 361 | 1.312 | 2.0e-6 |
| 5 | all_free | Optim.Fminbox(LBFGS(); Minuit metric, ReverseDiff) | ok | -2959.863974 | 0.003589 | 24 | 1.399 | 2.0e-6 |
| 6 | all_free | Minuit2.Migrad(strategy=2) | error | -2959.481635 | 0.385929 | 375 | 0.105 |  |
| 7 | all_free | Optim.Fminbox(BFGS()) | budget | -2959.038421 | 0.829143 | 501 | 1.010 |  |
| 8 | all_free | Optim.Fminbox(LBFGS()) | budget | -2954.723087 | 5.144476 | 501 | 3.234 |  |
| 9 | mass_only | Optim.Fminbox(BFGS()) | ok | -2933.364754 | 26.50281 | 298 | 0.893 |  |
| 10 | mass_only | Optim.Fminbox(LBFGS()) | ok | -2933.364754 | 26.50281 | 361 | 2.246 |  |
| 11 | mass_only | Minuit2.Migrad(strategy=1) | ok | -2933.364754 | 26.50281 | 18 | 0.180 | 0.0 |
| 12 | mass_only | Minuit2.Migrad(strategy=2) | error | -2933.364754 | 26.50281 | 25 | 0.016 |  |
| 13 | mass_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2933.364752 | 26.502811 | 16 | 0.834 | 1.0e-6 |
| 14 | mass_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2933.364752 | 26.502811 | 16 | 0.605 | 0.0 |
| 15 | mass_only | Optim.Fminbox(BFGS(); Minuit metric, ReverseDiff) | ok | -2933.364752 | 26.502811 | 5 | 0.028 | 1.0e-6 |
| 16 | mass_only | Optim.Fminbox(LBFGS(); Minuit metric, ReverseDiff) | ok | -2933.364752 | 26.502811 | 5 | 1.226 | 0.0 |
| 17 | yield_only | Optim.Fminbox(LBFGS()) | ok | -2923.404898 | 36.462666 | 414 | 4.311 |  |
| 18 | yield_only | Optim.Fminbox(BFGS()) | ok | -2923.404898 | 36.462666 | 463 | 1.021 |  |
| 19 | yield_only | Minuit2.Migrad(strategy=2) | error | -2923.404898 | 36.462666 | 160 | 0.734 |  |
| 20 | yield_only | Minuit2.Migrad(strategy=1) | ok | -2923.404898 | 36.462666 | 82 | 0.722 | 0.0 |
| 21 | yield_only | Optim.Fminbox(BFGS(); Minuit metric, ReverseDiff) | ok | -2923.404892 | 36.462672 | 8 | 0.020 | 3.0e-6 |
| 22 | yield_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2923.404892 | 36.462672 | 57 | 0.798 | 3.0e-6 |
| 23 | yield_only | Optim.Fminbox(LBFGS(); Minuit metric, ReverseDiff) | ok | -2923.404892 | 36.462672 | 8 | 0.875 | 3.0e-6 |
| 24 | yield_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2923.404892 | 36.462672 | 57 | 0.702 | 3.0e-6 |
| 25 | yield_only | Optim.NelderMead() | no | -2923.350201 | 36.517362 | 50 | 0.455 |  |
| 26 | all_free | Optim.NelderMead() | no | -2912.133943 | 47.73362 | 213 | 0.463 |  |
| 27 | shape_only | Minuit2.Migrad(strategy=2) | error | -2910.634352 | 49.233211 | 235 | 0.116 |  |
| 28 | shape_only | Minuit2.Migrad(strategy=1) | ok | -2910.634352 | 49.233212 | 195 | 0.498 | 2.0e-6 |
| 29 | shape_only | Optim.Fminbox(BFGS()) | budget | -2910.634329 | 49.233234 | 501 | 2.508 |  |
| 30 | shape_only | Optim.Fminbox(LBFGS()) | budget | -2910.634323 | 49.233241 | 501 | 2.508 |  |
| 31 | shape_only | Optim.Fminbox(BFGS(); Minuit metric) | ok | -2910.621827 | 49.245736 | 113 | 1.131 | 2.0e-6 |
| 32 | shape_only | Optim.Fminbox(BFGS(); Minuit metric, ReverseDiff) | ok | -2910.621826 | 49.245738 | 16 | 0.113 | 2.0e-6 |
| 33 | shape_only | Optim.Fminbox(LBFGS(); Minuit metric) | ok | -2910.604326 | 49.263237 | 78 | 0.634 | 7.0e-6 |
| 34 | shape_only | Optim.Fminbox(LBFGS(); Minuit metric, ReverseDiff) | ok | -2910.604325 | 49.263238 | 11 | 1.435 | 7.0e-6 |
| 35 | shape_only | Optim.NelderMead() | error | -2904.271919 | 55.595644 | 5 | 0.499 |  |
| 36 | yield_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.355 |  |
| 37 | mass_only | Optim.NelderMead() | ok | -2904.091787 | 55.775776 | 6 | 0.378 |  |
| 38 | mass_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.261 |  |
| 39 | shape_only | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.429 |  |
| 40 | all_free | Optim.ParticleSwarm() | error | -2904.091787 | 55.775776 | 2 | 0.245 |  |

Status: `ok` converged, `budget` hit the configured computation budget, `error` threw before convergence, `no` stopped without convergence.
