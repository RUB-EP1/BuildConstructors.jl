using BuildConstructors
import BuildConstructors: update!
using ComponentArrays
using NativeMinuit
using Test

@with_parameters(NativeQuadratic; a::P, b::P, offset::P, begin
    (a = a, b = b, offset = offset)
end)

quadratic_constructor() = ConstructorOfNativeQuadratic(
    AdvancedParameter("a", 0.0; boundaries = (-5.0, 5.0), uncertainty = 0.2),
    AdvancedParameter("b", 0.0; boundaries = (-4.0, 4.0), uncertainty = 0.3),
    AdvancedParameter("offset", 3.0; fixed = true),
)

@testset "NativeMinuit extension" begin
    @test Base.get_extension(BuildConstructors, :NativeMinuitExt) !== nothing

    @testset "fit configuration from constructor metadata" begin
        constructor = quadratic_constructor()
        callback_type = Ref{Any}()
        function objective(pars)
            callback_type[] = typeof(pars)
            model = build_model(constructor, pars)
            return (model.a - 1)^2 + (model.b - 2)^2 + model.offset
        end

        fit = Minuit(objective, constructor)
        # the fixed `offset` stays out of the fit vector
        @test fit.parameters == ("a", "b")
        @test fit.fcn.f === objective
        @test fit.params.values isa ComponentVector
        @test collect(fit.values) == [0.0, 0.0]
        @test collect(fit.errors) == [0.2, 0.3]
        @test collect(fit.limits) == [(-5.0, 5.0), (-4.0, 4.0)]

        migrad!(fit)
        @test callback_type[] <: ComponentVector
        @test fit.valid
        @test fit.values["a"] ≈ 1.0 atol = 2e-3
        @test fit.values["b"] ≈ 2.0 atol = 2e-3
        @test fit.fmin.ext_values isa ComponentVector
        @test fit.fmin.ext_errors isa ComponentVector

        fitted = copy(fit.values)
        @test fitted isa ComponentVector
        @test fitted.a ≈ 1.0 atol = 2e-3
        @test fitted.b ≈ 2.0 atol = 2e-3

        update!(constructor, fit)
        @test parameter_values(constructor).a ≈ fitted.a
        @test parameter_values(constructor).b ≈ fitted.b
        @test parameter_values(constructor).offset == 3.0
    end

    @testset "user gradient keeps the ComponentVector" begin
        constructor = quadratic_constructor()
        objective(pars) = (pars.a - 1)^2 + (pars.b - 2)^2
        gradient_type = Ref{Any}()
        function gradient(pars)
            gradient_type[] = typeof(pars)
            return ComponentArray(a = 2 * (pars.a - 1), b = 2 * (pars.b - 2))
        end

        fit = Minuit(objective, constructor; grad = gradient)
        @test fit.cfwg.g === gradient
        migrad!(fit)
        @test fit.valid
        @test gradient_type[] <: ComponentVector
    end

    @testset "starting values come from the descriptors" begin
        objective(pars) = (pars.a - 1)^2 + (pars.b - 2)^2

        constructor = quadratic_constructor()
        update!(constructor, (b = 1.5,))
        @test collect(Minuit(objective, constructor).values) == [0.0, 1.5]

        # `Running` stores no value, so the tree cannot describe the fit
        running_constructor = ConstructorOfNativeQuadratic(
            Running("a"),
            AdvancedParameter("b", 0.0; uncertainty = 0.2),
            Fixed(3.0),
        )
        @test_throws ArgumentError Minuit(objective, running_constructor)

        fit = Minuit(objective, constructor)
        migrad!(fit)
        @test fit.valid
    end

    # `fix!`/`release!` are exported by NativeMinuit too, so they stay qualified
    @testset "fixing and releasing" begin
        constructor = quadratic_constructor()
        BuildConstructors.fix!(constructor, (:b,))
        @test Minuit(pars -> (pars.a - 1)^2, constructor).parameters == ("a",)

        BuildConstructors.fix!(constructor)
        @test_throws ArgumentError Minuit(pars -> (pars.a - 1)^2, constructor)

        BuildConstructors.release!(constructor, (:a,))
        @test Minuit(pars -> (pars.a - 1)^2, constructor).parameters == ("a",)
    end
end
