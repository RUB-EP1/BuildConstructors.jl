using Test
using BuildConstructors

@with_parameters(AffineCore; slope::P, intercept::P, begin
    x -> slope * x + intercept
end)

@testset "Core functionality without weak dependencies" begin
    @test BuildConstructors.physics_models_extension() === nothing

    fixed = Fixed(2.0)
    running = Running("x")
    @test BuildConstructors.value(fixed; pars = (x = 3.0,)) == 2.0
    @test BuildConstructors.value(running; pars = (x = 3.0,)) == 3.0
    @test isequal(running_values(running), (x = missing,))

    constructor = ConstructorOfAffineCore(Fixed(2.0), Running("b"))
    model = build_model(constructor, (b = 1.5,))
    @test model(3.0) == 7.5
    @test isequal(running_values(constructor), (b = missing,))

    @test BuildConstructors._type_from_string("Fixed") === Fixed
    @test BuildConstructors._type_from_string("Int") === Int
    @test_throws ErrorException BuildConstructors._type_from_string("DefinitelyMissingType")
    @test_throws ErrorException BuildConstructors._type_from_string("Fixed{Float64}")

    eval_sentinel = Ref(false)
    payload = "begin eval_sentinel[] = true; Fixed end"
    @test_throws ErrorException BuildConstructors._type_from_string(payload)
    @test !eval_sentinel[]

    @test_throws ErrorException BuildConstructors._type_from_string("serialize")
end

# Load weak dependencies so PhysicsModelsExt is activated,
# then pull extension symbols into Main for the physics tests.
using Distributions
using DistributionsHEP
using JSON
using NumericalDistributions
include("physics_access.jl")

@testset "BuildConstructors tests" begin
    # let # to be replaced by the line above once working
    cCBpSECH_running_w = ConstructorOfCBpSECH(
        Fixed(0.002795),
        Fixed(2.48),
        Fixed(474),
        Fixed(8.1),
        Fixed(2.0),
        Fixed(1.3505),
        Fixed(0.5909),
        Running("w"),
        (1.1, 2.5),
    )
    model = build_model(cCBpSECH_running_w, (w = 0.5,))
    @test pdf(model, 1.1) == 1.2899706106958533

    cG_fixed_μ = ConstructorOfGaussian(Fixed(0), Running("σ"), (-0.5, 0.5))
    model = build_model(cG_fixed_μ, (σ = 0.1,))
    @test pdf(model, 0.1) == 2.4197086324179997


    cG_running_μ = ConstructorOfGaussian(Running("μ"), Running("σ"), (-0.5, 0.5))
    model = build_model(cG_running_μ, (μ = 0.0, σ = 0.1))
    @test pdf(model, 0.1) == 2.4197086324179997

    cG_fixed_μσ = ConstructorOfGaussian(Fixed(0), Fixed(0.1), (-0.5, 0.5))
    model = build_model(cG_fixed_μσ, NamedTuple())
    @test pdf(model, 0.1) == 2.4197086324179997
end



cM_running_w = ConstructorOfPRBModel(
    ConstructorOfBW(Fixed(3.8), Fixed(0.1), (1.0, 2.6)),
    ConstructorOfCBpSECH(
        Fixed(0.002795),
        Fixed(2.48),
        Fixed(474),
        Fixed(8.1),
        Fixed(2.0),
        Fixed(1.3505),
        Fixed(0.5909),
        Running("w"),
        (-0.5, 0.5),
    ),
    ConstructorOfPol1(Fixed(0.1), (1.0, 2.6)),
    Fixed(0.5),
    (1.1, 2.5),
    10000,
)

model = build_model(cM_running_w, (w = 0.5,))
@test pdf(model, 1.1) ≈ 0.45971088258516407


constructor, pars = load_prb_model_from_json(
    joinpath(@__DIR__, "..", "data", "database_test.json"),
    "bw",
    "CBpSECH",
    "Pol2",
)
model = build_model(constructor, pars)
@test pdf(model, 1.1) ≈ 0.01570665415299559






data = open(joinpath(@__DIR__, "test-serialization.json")) do f
    JSON.parse(f)
end

data["my_model"]["model_p"]



all_fields = data["my_model"]


let
    c, s = deserialize(Fixed, all_fields["model_p"]["description_of_m"])
    @test s == NamedTuple()
    @test c isa Fixed
    @test c.value == 2.1
end

let
    c, s = deserialize(Running, all_fields["model_r"]["description_of_σ"])
    @test s == (σ = 0.1,)
    @test c isa Running
    @test c.name == "σ"
end



let
    c, s = deserialize(ConstructorOfBW, all_fields["model_p"])
    @test s == NamedTuple()
    @test c isa ConstructorOfBW
end



let
    c, s = deserialize(ConstructorOfGaussian, all_fields["model_r"])
    @test s == (σ = 0.1,)
    @test c isa ConstructorOfGaussian
end


let
    c, s = deserialize(ConstructorOfPRBModel, data["my_model"])
    @test s == (σ = 0.1,)
    @test c isa ConstructorOfPRBModel
end

@testset "Serialization round-trip" begin
    # 1. Build a model constructor + parameters manually
    #=cM = ConstructorOfPRBModel(
        ConstructorOfBW(Fixed(1.0), Fixed(0.1), (1.0, 2.6)),
        ConstructorOfCBpSECH(Fixed(0.0028), Fixed(2.48), Fixed(474), Fixed(8.1), Fixed(2.0), Fixed(1.35), Fixed(0.59), Running("w"), (-0.5, 0.5)),
        ConstructorOfPol2(Fixed(0.1), Fixed(0.2), (1.0, 2.6)),
        Fixed(0.5),
        (1.1, 2.5)
    )=#

    #pars = (w = 0.5,)  # starting values for running variables

    cM, pars = load_prb_model_from_json(
        joinpath(@__DIR__, "..", "data", "database_test.json"),
        "bw",
        "CBpSECH",
        "Pol2",
    )

    # 2. Serialize to a JSON-like Dict
    ser = serialize(cM; pars)
    @test haskey(ser, "type")
    @test ser["type"] == "ConstructorOfPRBModel"

    # Optional: Write to JSON and read back to check compatibility
    # JSON.print("temp_model.json", ser)
    # ser2 = JSON.parsefile("temp_model.json")

    # 3. Deserialize back into a ConstructorOfPRBModel
    cM_reconstructed, pars_reconstructed = deserialize(ConstructorOfPRBModel, ser)

    # 4. Check model structure matches
    @test typeof(cM_reconstructed) == typeof(cM)

    # 5. Check that running parameters survived correctly
    @test pars_reconstructed === pars

    model1 = build_model(cM, pars)
    model2 = build_model(cM_reconstructed, pars_reconstructed)

    @test model1 isa Distribution
    @test model2 isa Distribution
    @test pdf(model1, 1.1) ≈ 0.01570665415299559
    @test pdf(model2, 1.1) ≈ 0.01570665415299559
end

@testset "Extend BuildConstructors" begin
    include("test-extend.jl")
end

@testset "Flexible Parameter" begin
    include("test-parameter.jl")
end
