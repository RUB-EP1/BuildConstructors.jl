module BuildConstructors

using OrderedCollections

# abstract parameter type
# and two simple primitives

export fix!
export release!
export update!
export parameter_metadata
export parameter_names
export running_names
export fixed_names
export parameter_values
export parameter_uncertainties
export parameter_upper_boundaries
export parameter_lower_boundaries
export running_values
export running_uncertainties
export running_upper_boundaries
export running_lower_boundaries
export fixed_values
export fixed_uncertainties
export fixed_upper_boundaries
export fixed_lower_boundaries
include("abstract-parameters.jl")

export Fixed
export Running
export FlexibleParameter
export AdvancedParameter
include("concrete-parameters.jl")

export build_model
include("abstract-constructor.jl")

export @with_parameters
include("macros.jl")

"""
    physics_models_extension()

Return the `PhysicsModelsExt` module once its weak dependencies
(`JSON`, `Distributions`, `DistributionsHEP`, `NumericalDistributions`) are loaded
in the Julia session; otherwise return `nothing`.

Built-in resonance- and resolution-style constructors (`ConstructorOfBW`, etc.)
and JSON helpers such as `load_prb_model_from_json` are defined there.
"""
physics_models_extension() = Base.get_extension(@__MODULE__, :PhysicsModelsExt)

export physics_models_extension

# IO
# registration mechanism
include("register-type.jl")

# serialization/deserialization
export serialize
export deserialize
include("io.jl")

end # module
