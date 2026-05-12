using BuildConstructors
using Documenter

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
    recursive = true,
)

makedocs(;
    modules = [BuildConstructors],
    sitename = "BuildConstructors.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://mikhailmikhasenko.github.io/BuildConstructors.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "Nested Constructors" => "tutorials/nested-constructors.md",
            "Optim with ComponentArrays" => "tutorials/optim-componentarrays.md",
            "Minuit2 with ComponentArrays" => "tutorials/minuit2-componentarrays.md",
        ],
    ],
    doctest = true,
    checkdocs = :exports,
)

deploydocs(;
    repo = "github.com/mikhailmikhasenko/BuildConstructors.jl.git",
    devbranch = "main",
)
