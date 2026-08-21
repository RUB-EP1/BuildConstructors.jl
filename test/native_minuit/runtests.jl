using BuildConstructors
import BuildConstructors: update!
using ComponentArrays
using NativeMinuit
using Test

@with_parameters(NativeQuadratic; a::P, b::P, offset::P, begin
    (a = a, b = b, offset = offset)
end)

function quadratic_constructor()
    return ConstructorOfNativeQuadratic(
        AdvancedParameter("a", 0.0; boundaries = (-5.0, 5.0), uncertainty = 0.2),
        AdvancedParameter("b", 0.0; boundaries = (-4.0, 4.0), uncertainty = 0.3),
        AdvancedParameter("offset", 3.0; fixed = true),
    )
end

@testset "NativeMinuit extension" begin
    @test Base.get_extension(BuildConstructors, :NativeMinuitExt) !== nothing

    @testset "bare ComponentVector works with NativeMinuit 0.7" begin
        start = ComponentArray(a = 0.0, b = 0.0)
        objective(pars) = (pars.a - 1)^2 + (pars.b - 2)^2
        bare_fit = Minuit(objective, start; name = ["a", "b"])
        migrad!(bare_fit)
        @test bare_fit.valid
        @test bare_fit.values["a"] ≈ 1.0 atol = 2e-3
        @test bare_fit.values["b"] ≈ 2.0 atol = 2e-3
    end

    @testset "constructor metadata and ComponentVector callback" begin
        constructor = quadratic_constructor()
        callback_type = Ref{Any}()
        function objective(pars)
            callback_type[] = typeof(pars)
            model = build_model(constructor, pars)
            return (model.a - 1)^2 + (model.b - 2)^2 + model.offset
        end

        fit = Minuit(objective, constructor)
        @test [parameter.name for parameter in fit.params.pars] == ["a", "b"]
        @test collect(fit.values) == [0.0, 0.0]
        @test collect(fit.errors) == [0.2, 0.3]
        @test collect(fit.limits) == [(-5.0, 5.0), (-4.0, 4.0)]

        migrad!(fit)
        @test callback_type[] <: ComponentVector
        @test fit.valid
        @test fit.values["a"] ≈ 1.0 atol = 2e-3
        @test fit.values["b"] ≈ 2.0 atol = 2e-3

        update!(constructor, fit)
        @test parameter_values(constructor).a ≈ fit.values["a"]
        @test parameter_values(constructor).b ≈ fit.values["b"]
        @test parameter_values(constructor).offset == 3.0
    end

    @testset "fixed parameters and explicit starts" begin
        constructor = quadratic_constructor()
        BuildConstructors.fix!(constructor, (:b,))
        fit = Minuit(pars -> (pars.a - 1)^2, constructor)
        @test [parameter.name for parameter in fit.params.pars] == ["a"]

        running_constructor = ConstructorOfNativeQuadratic(
            Running("a"),
            AdvancedParameter("b", 0.0; uncertainty = 0.2),
            Fixed(3.0),
        )
        objective(pars) = (pars.a - 1)^2 + (pars.b - 2)^2
        @test_throws ArgumentError Minuit(objective, running_constructor)

        fit_with_start = Minuit(
            objective,
            running_constructor;
            start = (a = 0.0,),
        )
        @test collect(fit_with_start.values) == [0.0, 0.0]

        fit_override = Minuit(
            objective,
            quadratic_constructor();
            start = (b = 1.5,),
        )
        @test fit_override.values["b"] == 1.5
        @test fit_override.values["a"] == 0.0
        migrad!(fit_with_start)
        @test fit_with_start.valid
    end
end
