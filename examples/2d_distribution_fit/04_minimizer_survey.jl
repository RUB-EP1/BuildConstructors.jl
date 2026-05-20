using Pkg

const SCRIPT_DIR = @__DIR__
Pkg.activate(SCRIPT_DIR)

include(joinpath(SCRIPT_DIR, "src", "two_dimensional_fit.jl"))
include(joinpath(SCRIPT_DIR, "src", "minimizer_survey.jl"))

using .TwoDimensionalFitExample
using .Fit2DMinimizerSurvey

function _sample(data, n)
    n >= length(data) && return data
    return data[1:n]
end

loaded = load_fit_data()
sample_size = parse(Int, get(ENV, "FIT2D_SAMPLE_SIZE", "250"))
maxiters = parse(Int, get(ENV, "FIT2D_MAXITERS", "25"))
max_objective_calls = parse(Int, get(ENV, "FIT2D_MAX_CALLS", "500"))
max_seconds = parse(Float64, get(ENV, "FIT2D_MAX_SECONDS", "20.0"))
append_scoreboard = lowercase(get(ENV, "FIT2D_APPEND", "true")) in ("1", "true", "yes")
data = _sample(loaded.data2d, sample_size)

results = run_survey(data; maxiters, max_objective_calls, max_seconds)

outdir = joinpath(SCRIPT_DIR, "results")
csv_path = write_results_csv(joinpath(outdir, "minimizer_survey.csv"), results; append = append_scoreboard)
md_path = write_markdown_summary(joinpath(outdir, "minimizer_survey.md"), results)

println("Wrote ", csv_path)
println("Wrote ", md_path)
