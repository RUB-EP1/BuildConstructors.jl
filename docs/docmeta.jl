using Documenter: DocMeta
using BuildConstructors

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
