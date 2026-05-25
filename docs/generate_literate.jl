using Literate

Literate.markdown(
    joinpath(@__DIR__, "literate", "tutorials", "2d-model-construction.jl"),
    joinpath(@__DIR__, "src", "tutorials");
    documenter=true,
    execute=true,
    credit=false,
)
