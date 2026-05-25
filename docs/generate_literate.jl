using Literate

const LITERATE_TUTORIALS = [
    "2d-model-construction.jl",
    "2d-minuit2-fit.jl",
]

for tutorial in LITERATE_TUTORIALS
    Literate.markdown(
        joinpath(@__DIR__, "literate", "tutorials", tutorial),
        joinpath(@__DIR__, "src", "tutorials");
        documenter=false,
        execute=false,
        credit=false,
    )
end
