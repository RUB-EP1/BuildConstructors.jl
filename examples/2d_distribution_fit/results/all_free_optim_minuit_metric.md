# 2D fit minimizer survey

Generated: 2026-05-17 23:12:53

| stage | method | bounded | events | maxiters | calls | max calls | max seconds | converged | iterations | best nll | edm | seconds | budget | errored |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| all_free | Optim.Fminbox(LBFGS(); Minuit metric) | true | 10090 | 100 | 1501 | 1500 | 60.000 | false |  | -157305.023376 | 9.083348736147851 | 14.985 | true | true |
| all_free | Optim.Fminbox(BFGS(); Minuit metric) | true | 10090 | 100 | 1501 | 1500 | 60.000 | false |  | -157304.891322 | 0.19819975285799174 | 12.763 | true | true |
