using Arrow
using ComponentArrays
using DataFrames
using Optim

include(joinpath(@__DIR__, "..", "..", "examples", "2d_distribution_fit", "src", "two_dimensional_fit.jl"))
include(joinpath(@__DIR__, "..", "..", "examples", "2d_distribution_fit", "src", "Minuit2CAInterface.jl"))
include(joinpath(@__DIR__, "..", "..", "examples", "2d_distribution_fit", "src", "minimizer_survey.jl"))

using .TwoDimensionalFitExample
using .Minuit2CAInterface: Minuit2CA
using .Fit2DMinimizerSurvey

@testset "2D distribution fit example" begin
    @test isfile(data_path())

    raw = DataFrame(Arrow.Table(data_path()))
    @test all([:mKK1, :mKK2] .∈ Ref(Symbol.(names(raw))))

    loaded = load_fit_data()
    @test size(loaded.fit_df, 1) > 0
    @test length(loaded.data2d) == size(loaded.fit_df, 1)
    @test all(x -> KK_LIMITS[1] < x[1] < KK_LIMITS[2], loaded.data2d)
    @test all(x -> KK_LIMITS[1] < x[2] < KK_LIMITS[2], loaded.data2d)

    constructor = build_2d_constructor(size(loaded.fit_df, 1))
    pars = ComponentArray(running_values(constructor))
    @test Set(keys(pars)) ==
          Set((:y_phiphi, :y_mixed, :y_kkkk, :mu_B, :sigma_B, :alpha_B, :k_bkg_kk))

    lower = ComponentArray(running_lower_boundaries(constructor))
    upper = ComponentArray(running_upper_boundaries(constructor))
    @test all(lower .<= pars .<= upper)
    @test lower.y_phiphi == 0.0
    @test lower.y_mixed == 0.0
    @test lower.y_kkkk == 0.0

    model = build_model(constructor, pars)
    @test total_yield(model) ≈ size(loaded.fit_df, 1)
    @test isfinite(extended_negative_log_likelihood(model, loaded.data2d[1:10]))

    fix!(constructor)
    release!(constructor, (:y_phiphi, :y_mixed, :y_kkkk))
    @test free_parameter_names(constructor) == (:y_phiphi, :y_mixed, :y_kkkk)
    result = fit!(
        constructor,
        loaded.data2d[1:25];
        method = Fminbox(LBFGS()),
        options = Optim.Options(iterations = 2),
    )
    @test result.best_pars isa ComponentArray
    @test keys(result.best_pars) == (:y_phiphi, :y_mixed, :y_kkkk)
    lower_yields = ComponentArray(
        (
            y_phiphi = lower.y_phiphi,
            y_mixed = lower.y_mixed,
            y_kkkk = lower.y_kkkk,
        ),
    )
    @test all(result.best_pars .>= lower_yields)
end

@testset "Minuit2 ComponentArray interface" begin
    initial = ComponentArray(a = 1.0, b = 2.0)
    lower = ComponentArray(a = -10.0, b = -10.0)
    upper = ComponentArray(a = 10.0, b = 10.0)
    errors = ComponentArray(a = 0.25, b = 0.5)

    result = Minuit2CAInterface.optimize(
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

    @test Minuit2CAInterface.minimizer(result) isa ComponentArray
    @test keys(Minuit2CAInterface.minimizer(result)) == (:a, :b)
    @test Minuit2CAInterface.minimum(result) < 1e-3
    @test Minuit2CAInterface.converged(result)
    @test Minuit2CAInterface.original(result).names == ["a", "b"]
    @test Minuit2CAInterface.original(result).limits == [(-10.0, 10.0), (-10.0, 10.0)]
    @test Minuit2CAInterface._minuit_keywords(initial, Minuit2CA(; errors))[:error] == collect(errors)
    @test Minuit2CAInterface.hesse!(result; strategy = 1, maxcalls = 20) === result
    @test Minuit2CAInterface.original(result).errors isa ComponentArray
end

@testset "2D minimizer survey budgets" begin
    loaded = load_fit_data()
    stages = [StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "budget smoke test")]
    methods = [MethodSpec("Optim.Fminbox(LBFGS())", () -> Fminbox(LBFGS()), true, "budget smoke test")]

    results = run_survey(
        loaded.data2d[1:10];
        stages,
        methods,
        maxiters = 5,
        max_objective_calls = 1,
        max_seconds = 30.0,
    )

    @test length(results) == 1
    @test results[1].budget_exceeded
    @test results[1].objective_calls == 2
    @test results[1].budget_reason == "objective call budget exceeded"
end

@testset "2D tuned Optim survey setup" begin
    loaded = load_fit_data()
    stages = [StageSpec("yield_only", (:y_phiphi, :y_mixed, :y_kkkk), "tuned Optim smoke test")]
    methods = [MethodSpec(
        "Optim.Fminbox(BFGS(); Minuit metric)",
        () -> (tolerance = 0.01, errordef = 0.5),
        true,
        :optim_minuit_bfgs,
        "tuned Optim smoke test",
    )]

    results = run_survey(
        loaded.data2d[1:10];
        stages,
        methods,
        maxiters = 1,
        max_objective_calls = 20,
        max_seconds = 30.0,
    )

    @test length(results) == 1
    @test results[1].objective_calls > 0
    @test results[1].error_type != "MethodError"
end
