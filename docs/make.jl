using BuildConstructors
using Documenter
using Documenter: DocMeta, doctest
using Literate

const GITHUB_REPO = "https://github.com/RUB-EP1/BuildConstructors.jl"

DocMeta.setdocmeta!(
    BuildConstructors,
    :DocTestSetup,
    quote
        using Distributions
        using DistributionsHEP
        using JSON
        using NumericalDistributions
        using BuildConstructors
        Ext = physics_models_extension()
        Ext === nothing &&
            throw(ErrorException("PhysicsModelsExt inactive in DocTestSetup."))
    end;
    recursive=true,
)

bc_docs_doctest_only = get(ENV, "BC_DOCS_DOCTEST_ONLY", "false") == "true"
bc_docs_doctest_only && doctest(BuildConstructors)

!bc_docs_doctest_only && begin
    const LITERATE_TUTORIALS = [
        "2d-fit-benchmark-framework.jl",
        "2d-minuit2-componentarrays-study.jl",
        "2d-optim-minuit-settings.jl",
        "2d-optim-derivatives.jl",
        "2d-staged-fit-strategies.jl",
        "2d-default-optimizer-survey.jl",
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
                "2D Fit Benchmark Framework" => "tutorials/2d-fit-benchmark-framework.md",
                "2D Minuit2 Study" => "tutorials/2d-minuit2-componentarrays-study.md",
                "2D Optim Minuit Settings" => "tutorials/2d-optim-minuit-settings.md",
                "2D Optim Derivatives" => "tutorials/2d-optim-derivatives.md",
                "2D Staged Fit Strategies" => "tutorials/2d-staged-fit-strategies.md",
                "2D Default Optimizer Survey" => "tutorials/2d-default-optimizer-survey.md",
            ],
        ],
        checkdocs=:exports,
    )

    deploydocs(;
        repo="github.com/RUB-EP1/BuildConstructors.jl.git",
        devbranch="main",
    )
end
