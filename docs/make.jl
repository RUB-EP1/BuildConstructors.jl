using BuildConstructors
using Documenter

DocMeta.setdocmeta!(
    BuildConstructors,
    :DocTestSetup,
    :(using BuildConstructors);
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
