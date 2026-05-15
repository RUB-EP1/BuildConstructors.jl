using BuildConstructors
using ComponentArrays
using Test

constructor = ConstructorOfPRBModel(
    ConstructorOfBW(FlexibleParameter("m", 2.0), FlexibleParameter("Γ", 0.2), (1.0, 2.5)),
    ConstructorOfGaussian(Fixed(0.0), Running("σ"), (-0.5, 0.5)),
    ConstructorOfPol1(FlexibleParameter("c1", 0.3), (1.0, 2.5)),
    AdvancedParameter("fs", 0.5; boundaries = (0.0, 1.0), uncertainty = 0.01),
    (1.0, 2.5),
    10000,
)

@testset "FlexibleParameter is mutable" begin
    @test constructor.model_p.description_of_m.fixed == false
    setfield!(constructor.model_p.description_of_m, :fixed, true)
    @test getfield(constructor.model_p.description_of_m, :fixed) == true
    setfield!(constructor.model_p.description_of_m, :fixed, false)
    @test getfield(constructor.model_p.description_of_m, :fixed) == false
end


# tests
@testset "fix and release, one argument" begin
    fix!(constructor.model_p, (:m,))
    @test constructor.model_p.description_of_m.fixed == true
    release!(constructor.model_p, (:m,))
    @test constructor.model_p.description_of_m.fixed == false
end

@testset "fix and release, few argument" begin
    fix!(constructor, (:m, :Γ, :c1))
    @test constructor.model_p.description_of_m.fixed == true
    @test constructor.model_p.description_of_Γ.fixed == true
    @test constructor.model_b.description_of_c1C.fixed == true
    release!(constructor, (:m, :Γ, :c1))
    @test constructor.model_p.description_of_m.fixed == false
    @test constructor.model_p.description_of_Γ.fixed == false
    @test constructor.model_b.description_of_c1C.fixed == false
end

@testset "Fix and release works with array" begin
    fix!(constructor, [:m, :Γ, :c1])
    @test constructor.model_p.description_of_m.fixed == true
    @test constructor.model_p.description_of_Γ.fixed == true
    @test constructor.model_b.description_of_c1C.fixed == true
    release!(constructor, [:m, :Γ, :c1])
    @test constructor.model_p.description_of_m.fixed == false
    @test constructor.model_p.description_of_Γ.fixed == false
    @test constructor.model_b.description_of_c1C.fixed == false
end


@testset "Update and pickup" begin
    @test parameter_values(constructor.model_p) == (m = 2.0, Γ = 0.2)
    update!(constructor.model_p, (m = 1.9, Γ = 0.1))
    @test parameter_values(constructor.model_p) == (m = 1.9, Γ = 0.1)
    @test parameter_values(constructor) |> keys == (:m, :Γ, :σ, :c1, :fs)
    update!(constructor.model_p, (m = 2.0, Γ = 0.2))
end

@testset "Update works with ComponentArray" begin
    @test parameter_values(constructor.model_p) == (m = 2.0, Γ = 0.2)
    update!(constructor.model_p, ComponentArray(m = 1.9, Γ = 0.1))
    @test parameter_values(constructor.model_p) == (m = 1.9, Γ = 0.1)
    update!(constructor.model_p, (m = 2.0, Γ = 0.2))
end

@testset "released_values" begin
    release!(constructor)
    @test isequal(released_values(Fixed(1.0)), NamedTuple())
    @test isequal(released_values(Running("x")), (x = missing,))
    @test isequal(fixed_values(Fixed(1.0)), NamedTuple())
    @test isequal(fixed_values(Running("x")), NamedTuple())
    @test isequal(released_values(constructor), (m = 2.0, Γ = 0.2, σ = missing, c1 = 0.3, fs = 0.5))
    @test isequal(fixed_values(constructor), NamedTuple())

    fix!(constructor, (:m, :c1, :fs))
    @test isequal(parameter_values(constructor), (m = 2.0, Γ = 0.2, σ = missing, c1 = 0.3, fs = 0.5))
    @test isequal(running_values(constructor), parameter_values(constructor))
    @test isequal(released_values(constructor), (Γ = 0.2, σ = missing))
    @test isequal(fixed_values(constructor), (m = 2.0, c1 = 0.3, fs = 0.5))
    @test isequal(
        merge(fixed_values(constructor), released_values(constructor)),
        (m = 2.0, c1 = 0.3, fs = 0.5, Γ = 0.2, σ = missing),
    )

    release!(constructor, (:m, :fs))
    @test isequal(released_values(constructor), (m = 2.0, Γ = 0.2, σ = missing, fs = 0.5))
    @test isequal(fixed_values(constructor), (c1 = 0.3,))
end

@testset "Release all, and fix all" begin
    release!(constructor)
    @test constructor.model_p.description_of_m.fixed == false
    @test constructor.model_p.description_of_Γ.fixed == false
    @test constructor.model_b.description_of_c1C.fixed == false
    @test constructor.description_of_fs.fixed == false
    fix!(constructor)
    @test constructor.model_p.description_of_m.fixed == true
    @test constructor.model_p.description_of_Γ.fixed == true
    @test constructor.model_b.description_of_c1C.fixed == true
    @test constructor.description_of_fs.fixed == true
end

@testset "parameter_uncertainties" begin
    # Test on Running
    r = Running("σ")
    @test parameter_uncertainties(r) === (σ = missing,)

    # Test on Fixed
    f = Fixed(0.5)
    @test parameter_uncertainties(f) == NamedTuple()

    # Test on constructor - should collect from all fields
    # The constructor has: FlexibleParameter("m"), FlexibleParameter("Γ"), Fixed(0.0), Running("σ"), FlexibleParameter("c1"), FlexibleParameter("fs")
    # Only Running("σ") should contribute
    @test parameter_uncertainties(constructor) ===
          (m = missing, Γ = missing, σ = missing, c1 = missing, fs = 0.01)
    @test keys(parameter_uncertainties(constructor)) == keys(parameter_values(constructor))
    @test isequal(running_uncertainties(constructor), parameter_uncertainties(constructor))
end

@testset "parameter_upper_boundaries" begin
    # Test on individual FlexibleParameter
    p = FlexibleParameter("test", 1.0)
    @test parameter_upper_boundaries(p) == (test = Inf,)

    # Test on Running
    r = Running("σ")
    @test parameter_upper_boundaries(r) == (σ = Inf,)

    # Test on Fixed
    f = Fixed(0.5)
    @test parameter_upper_boundaries(f) == NamedTuple()

    # Test on constructor - should collect from all fields
    # The constructor has: FlexibleParameter("m"), FlexibleParameter("Γ"), Fixed(0.0), Running("σ"), FlexibleParameter("c1"), FlexibleParameter("fs")
    # All FlexibleParameters and Running should contribute with Inf
    upper_bounds = parameter_upper_boundaries(constructor)
    @test keys(upper_bounds) == keys(parameter_values(constructor))
    @test upper_bounds.m == Inf
    @test upper_bounds.Γ == Inf
    @test upper_bounds.σ == Inf
    @test upper_bounds.c1 == Inf
    @test upper_bounds.fs == 1.0
    @test keys(upper_bounds) == (:m, :Γ, :σ, :c1, :fs)

    p_default = AdvancedParameter("advanced", 1.0)
    @test parameter_upper_boundaries(p_default) == (advanced = Inf,)
    @test isequal(running_upper_boundaries(constructor), parameter_upper_boundaries(constructor))
end

@testset "parameter_lower_boundaries" begin
    # Test on individual FlexibleParameter
    p = FlexibleParameter("test", 1.0)
    @test parameter_lower_boundaries(p) == (test = -Inf,)

    # Test on Running
    r = Running("σ")
    @test parameter_lower_boundaries(r) == (σ = -Inf,)

    # Test on Fixed
    f = Fixed(0.5)
    @test parameter_lower_boundaries(f) == NamedTuple()

    # Test on constructor - should collect from all fields
    # The constructor has: FlexibleParameter("m"), FlexibleParameter("Γ"), Fixed(0.0), Running("σ"), FlexibleParameter("c1"), FlexibleParameter("fs")
    # All FlexibleParameters and Running should contribute with -Inf
    lower_bounds = parameter_lower_boundaries(constructor)
    @test keys(lower_bounds) == keys(parameter_values(constructor))
    @test lower_bounds.m == -Inf
    @test lower_bounds.Γ == -Inf
    @test lower_bounds.σ == -Inf
    @test lower_bounds.c1 == -Inf
    @test lower_bounds.fs == 0.0
    @test keys(lower_bounds) == (:m, :Γ, :σ, :c1, :fs)

    p_default = AdvancedParameter("advanced", 1.0)
    @test parameter_lower_boundaries(p_default) == (advanced = -Inf,)
    @test isequal(running_lower_boundaries(constructor), parameter_lower_boundaries(constructor))
end
