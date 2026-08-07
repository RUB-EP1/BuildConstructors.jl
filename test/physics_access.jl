# Bring PhysicsModelsExt bindings into scope (extension module is not a BuildConstructors.* submodule binding).
_phys = BuildConstructors.physics_models_extension()
_phys === nothing && error(
    "PhysicsModelsExt did not activate. Load JSON, Distributions, DistributionsHEP, and NumericalDistributions before BuildConstructors.",
)
const ConstructorOfBW = _phys.ConstructorOfBW
const ConstructorOfBraaten = _phys.ConstructorOfBraaten
const ConstructorOfCBpSECH = _phys.ConstructorOfCBpSECH
const ConstructorOfGaussian = _phys.ConstructorOfGaussian
const ConstructorOfPol1 = _phys.ConstructorOfPol1
const ConstructorOfPol2 = _phys.ConstructorOfPol2
const ConstructorOfPRBModel = _phys.ConstructorOfPRBModel
const convert_database_to_prb = _phys.convert_database_to_prb
const load_prb_model_from_json = _phys.load_prb_model_from_json
