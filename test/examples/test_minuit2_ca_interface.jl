using ComponentArrays

include(joinpath(@__DIR__, "..", "..", "examples", "2d_distribution_fit", "src", "Minuit2CAInterface.jl"))

using .Minuit2CAInterface: Minuit2CA, Minuit2CAInterface, converged, hesse!, minimizer, minimum, optimize, original

@testset "Minuit2 ComponentArray interface" begin
    initial = ComponentArray(a = 1.0, b = 2.0)
    lower = ComponentArray(a = -10.0, b = -10.0)
    upper = ComponentArray(a = 10.0, b = 10.0)
    errors = ComponentArray(a = 0.25, b = 0.5)

    result = optimize(
        x -> sum(abs2, x),
        initial,
        Minuit2CA(;
            errors,
            lower,
            upper,
            maxcalls = 50,
            tolerance = 0.01,
        ),
    )

    @test minimizer(result) isa ComponentArray
    @test keys(minimizer(result)) == (:a, :b)
    @test minimum(result) < 1e-3
    @test converged(result)
    @test original(result).names == ["a", "b"]
    @test original(result).limits == [(-10.0, 10.0), (-10.0, 10.0)]
    @test hesse!(result; strategy = 1, maxcalls = 20) === result
    @test original(result).errors isa ComponentArray
end
