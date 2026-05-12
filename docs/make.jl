using BuildConstructors
using Documenter

const GITHUB_REPO = "https://github.com/RUB-EP1/BuildConstructors.jl"

include(joinpath(@__DIR__, "docmeta.jl"))

makedocs(;
    modules=[BuildConstructors],
    authors="Robert Hentges <robert.hentges@cern.ch> and Mikhail Mikhasenko <mikhail.mikhasenko@cern.ch>",
    repo=GITHUB_REPO * "/blob/{commit}{path}#{line}",
    sitename="BuildConstructors.jl",
    doctest=true,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://RUB-EP1.github.io/BuildConstructors.jl",
        repolink=GITHUB_REPO,
    ),
    pages=[
        "Home" => "index.md",
        "Tutorials" => [
            "Nested Constructors" => "tutorials/nested-constructors.md",
            "Optim with ComponentArrays" => "tutorials/optim-componentarrays.md",
            "Minuit2 with ComponentArrays" => "tutorials/minuit2-componentarrays.md",
        ],
    ],
    checkdocs=:exports,
)

deploydocs(; repo="github.com/RUB-EP1/BuildConstructors.jl.git")
