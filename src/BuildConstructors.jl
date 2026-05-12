module BuildConstructors

using Distributions
using NumericalDistributions
using DistributionsHEP
using OrderedCollections
using Parameters

# abstract parameter type
# and two simple primitives

export fix!
export release!
export update!
export running_values
export running_uncertainties
export running_upper_boundaries
export running_lower_boundaries
include("abstract-parameters.jl")

export Fixed
export Running
export FlexibleParameter
export AdvancedParameter
include("concrete-parameters.jl")

export build_model
export ConstructorOfBW
export ConstructorOfBraaten
export ConstructorOfCBpSECH
export ConstructorOfGaussian
export ConstructorOfPol1
export ConstructorOfPol2
include("abstract-constructor.jl")

export @with_parameters
include("macros.jl")

include("primitives.jl")

# IO
# registration mechanism
include("register-type.jl")

# serialization/deserialization
export serialize
export deserialize
include("io.jl")

# domain-specific PRB workflow
export ConstructorOfPRBModel
export convert_database_to_prb
export load_prb_model_from_json
include("prb-model.jl")

end # module
