using BuildConstructors
using Test

cg = ConstructorOfGaussian(Fixed(0.0), Running("σ"), (-0.5, 0.5))

cg_ser = serialize(cg; pars = (σ = 0.1,))
cg_des = deserialize(ConstructorOfGaussian, cg_ser)[1]

@test cg_des == cg

# Custom parameter type: register the name, generic field serialization handles the rest.
struct FirstParameter <: BuildConstructors.AbstractParameter end
BuildConstructors.value(c::FirstParameter; pars) = pars |> first
BuildConstructors.register!(FirstParameter)

cg2 = ConstructorOfGaussian(FirstParameter(), Running("σ"), (-0.5, 0.5))

cg2_ser = serialize(cg2; pars = (σ = 0.1,))
cg2_des = deserialize(ConstructorOfGaussian, cg2_ser)[1]

@test cg2_des == cg2
