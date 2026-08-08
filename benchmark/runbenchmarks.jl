using BenchmarkTools
using BuildConstructors
using ComponentArrays
using Distributions
using DistributionsHEP
using JSON
using NumericalDistributions
using Printf
using Statistics

const Phys = BuildConstructors.physics_models_extension()
Phys === nothing && error("Load BuildConstructors weak dependencies before running benchmarks.")

const ConstructorOfBW = Phys.ConstructorOfBW
const ConstructorOfCBpSECH = Phys.ConstructorOfCBpSECH
const ConstructorOfGaussian = Phys.ConstructorOfGaussian
const ConstructorOfPol1 = Phys.ConstructorOfPol1
const ConstructorOfPRBModel = Phys.ConstructorOfPRBModel
const load_prb_model_from_json = Phys.load_prb_model_from_json

@with_parameters(BenchGauss; μ::P, σ::P, support::Tuple{Float64,Float64}, begin
    truncated(Normal(μ, σ), support...)
end)

@with_parameters(BenchMixture; left, right, f_left::P, begin
    MixtureModel(
        [build_model(left, pars), build_model(right, pars)],
        [f_left, 1 - f_left],
    )
end)

function gaussian_direct(pars, support)
    return truncated(Normal(pars.μ, pars.σ), support...)
end

function mixture_direct(pars)
    left = truncated(Normal(pars.μ_left, pars.σ_left), -5.0, 5.0)
    right = truncated(Normal(pars.μ_right, pars.σ_right), -5.0, 5.0)
    return MixtureModel([left, right], [pars.f_left, 1 - pars.f_left])
end

function prb_direct(pars; grid_size = 10_000, support = (1.1, 2.5))
    p = NumericallyIntegrable(
        e -> 1 / abs2(3.8^2 - e^2 - 1im * 3.8 * 0.1),
        (1.0, 2.6),
    )
    σ1, c0, c1, c2, n, s, fr1 = 0.002795, 2.48, 474.0, 8.1, 2.0, 1.3505, 0.5909
    w = pars.w
    σ2 = s * σ1
    σ1_MeV, σ2_MeV = (σ1, σ2) .* 1e3
    α = c0 * (c1 * σ1)^c2 / (1 + (c1 * σ1)^c2)
    d1 = CrystalBall(0.0, σ1_MeV, α, n)
    td1 = truncated(d1, support[1], support[2])
    hyp_sec(x, μ, σ) = 1 / (2 * σ) * sech(π / 2 * (x - μ) / σ)
    td2 = NumericallyIntegrable(x -> hyp_sec(x, 0.0, σ2_MeV), support)
    r = w * MixtureModel([td1, td2], [fr1, 1 - fr1])
    b = Chebyshev([1, 0.1], 1.0, 2.6)
    r_conv_p = truncated(fft_convolve(r, p; gridsize = grid_size), support[1], support[2])
    return MixtureModel([r_conv_p, b], [0.5, 0.5])
end

function make_gaussian_case()
    support = (-0.5, 0.5)
    constructor = ConstructorOfBenchGauss(
        AdvancedParameter("μ", 0.0; boundaries = (-5.0, 5.0), uncertainty = 0.1),
        AdvancedParameter("σ", 0.1; boundaries = (0.01, 5.0), uncertainty = 0.01),
        support,
    )
    pars = (μ = 0.0, σ = 0.1)
    return (; constructor, pars, support, label = "Gaussian (2 params)")
end

function make_mixture_case()
    constructor = ConstructorOfBenchMixture(
        ConstructorOfBenchGauss(
            AdvancedParameter("μ_left", -0.5; boundaries = (-5.0, 5.0), uncertainty = 0.1),
            AdvancedParameter("σ_left", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.05),
            (-5.0, 5.0),
        ),
        ConstructorOfBenchGauss(
            AdvancedParameter("μ_right", 0.7; boundaries = (-5.0, 5.0), uncertainty = 0.1),
            AdvancedParameter("σ_right", 1.0; boundaries = (0.05, 5.0), uncertainty = 0.05),
            (-5.0, 5.0),
        ),
        AdvancedParameter("f_left", 0.5; boundaries = (0.0, 1.0), uncertainty = 0.02),
    )
    pars = (μ_left = -0.5, σ_left = 1.0, μ_right = 0.7, σ_right = 1.0, f_left = 0.5)
    return (; constructor, pars, label = "Nested mixture (5 params)")
end

function make_prb_case()
    constructor = ConstructorOfPRBModel(
        Fixed(0.5),
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
        (1.1, 2.5),
        10_000,
    )
    pars = (w = 0.5,)
    return (; constructor, pars, label = "PRB physics model (1 running param)")
end

function make_json_prb_case()
    database = joinpath(@__DIR__, "..", "data", "database_test.json")
    constructor, pars = load_prb_model_from_json(database, "bw", "CBpSECH", "Pol2")
    return (; constructor, pars, label = "PRB from JSON (6 running params)")
end

function median_ns(bench)
    return median(bench.times) / 1e3
end

function overhead_ratio(bc_ns, direct_ns)
    return bc_ns / direct_ns
end

function memory_bytes(obj)
    return Base.summarysize(obj)
end

function format_bytes(n::Integer)
    if n >= 1_048_576
        return @sprintf("%.2f MiB", n / 1_048_576)
    elseif n >= 1024
        return @sprintf("%.1f KiB", n / 1024)
    else
        return @sprintf("%d B", n)
    end
end

function format_time(ns::Real)
    if ns >= 1000
        return @sprintf("%.2f μs", ns / 1000)
    else
        return @sprintf("%.1f ns", ns)
    end
end

function benchmark_build(case; samples = 30, evals = 1)
    constructor = case.constructor
    pars = case.pars
    fast = haskey(case, :support) || case.label == "Nested mixture (5 params)"
    evals = fast ? 100 : evals

    bc_bench = @benchmark build_model($constructor, $pars) samples = samples evals = evals

    direct_bench = if haskey(case, :support)
        support = case.support
        @benchmark gaussian_direct($pars, $support) samples = samples evals = evals
    elseif case.label == "Nested mixture (5 params)"
        @benchmark mixture_direct($pars) samples = samples evals = evals
    elseif case.label == "PRB physics model (1 running param)"
        @benchmark prb_direct($pars) samples = samples evals = evals
    else
        nothing
    end

    bc_ns = median_ns(bc_bench) / evals
    direct_ns = direct_bench === nothing ? missing : median_ns(direct_bench) / evals
    ratio = direct_ns === missing ? missing : overhead_ratio(bc_ns, direct_ns)

    model = build_model(constructor, pars)
    return (;
        label = case.label,
        build_bc_ns = bc_ns,
        build_direct_ns = direct_ns,
        build_ratio = ratio,
        constructor_bytes = memory_bytes(constructor),
        model_bytes = memory_bytes(model),
    )
end

function benchmark_metadata(case; samples = 100, evals = 10)
    constructor = case.constructor
    return (;
        running_values = median_ns(@benchmark running_values($constructor) samples = samples evals = evals) / evals,
        running_names = median_ns(@benchmark running_names($constructor) samples = samples evals = evals) / evals,
        parameter_metadata = median_ns(@benchmark parameter_metadata($constructor) samples = samples evals = evals) / evals,
    )
end

function evaluate_likelihood(model, x)
    return -sum(logpdf.(Ref(model), x))
end

function benchmark_fit_step(case, x; samples = 20, evals = 1)
    constructor = case.constructor
    pars = case.pars
    use_pdf = case.label == "PRB physics model (1 running param)"
    fast = !use_pdf
    evals = fast ? 50 : evals

    bc_bench = if use_pdf
        @benchmark begin
            model = build_model($constructor, $pars)
            sum(pdf.(Ref(model), $x))
        end samples = samples evals = evals
    else
        @benchmark begin
            model = build_model($constructor, $pars)
            evaluate_likelihood(model, $x)
        end samples = samples evals = evals
    end

    direct_bench = if haskey(case, :support)
        support = case.support
        @benchmark begin
            model = gaussian_direct($pars, $support)
            evaluate_likelihood(model, $x)
        end samples = samples evals = evals
    elseif use_pdf
        @benchmark begin
            model = prb_direct($pars)
            sum(pdf.(Ref(model), $x))
        end samples = samples evals = evals
    else
        nothing
    end

    bc_ns = median_ns(bc_bench) / evals
    direct_ns = direct_bench === nothing ? missing : median_ns(direct_bench) / evals
    ratio = direct_ns === missing ? missing : overhead_ratio(bc_ns, direct_ns)

    return (;
        label = case.label,
        nll_bc_ns = bc_ns,
        nll_direct_ns = direct_ns,
        nll_ratio = ratio,
    )
end

function print_table(title, rows, columns)
    println()
    println(title)
    println("="^length(title))
    headers = string.(columns)
    col_widths = [
        max(
            length(headers[i]),
            maximum(length(string(getproperty(row, col))) for row in rows),
        ) for (i, col) in enumerate(columns)
    ]
    println(join((rpad(headers[i], col_widths[i]) for i in 1:length(columns)), " | "))
    println("-"^(sum(col_widths) + 3 * (length(columns) - 1)))
    for row in rows
        values = String[]
        for (i, col) in enumerate(columns)
            val = getproperty(row, col)
            sval = val === missing ? "—" : string(val)
            push!(values, rpad(sval, col_widths[i]))
        end
        println(join(values, " | "))
    end
end

function format_ratio(ratio)
    ratio === missing && return "—"
    return @sprintf("%.2fx", ratio)
end

function main()
    cases = [make_gaussian_case(), make_mixture_case(), make_prb_case(), make_json_prb_case()]

    build_rows = map(c -> begin
        row = benchmark_build(c)
        (;
            label = row.label,
            build_bc_ns = format_time(row.build_bc_ns),
            build_direct_ns = row.build_direct_ns === missing ? missing : format_time(row.build_direct_ns),
            build_ratio = format_ratio(row.build_ratio),
        )
    end, cases)
    metadata_rows = [
        begin
            meta = benchmark_metadata(c)
            (;
                label = c.label,
                running_values = format_time(meta.running_values),
                running_names = format_time(meta.running_names),
                parameter_metadata = format_time(meta.parameter_metadata),
            )
        end for c in cases
    ]

    x_gauss = randn(1000)
    x_prb = 1.1 .+ 0.1 .* rand(1000)
    fit_rows = [
        begin
            row = benchmark_fit_step(make_gaussian_case(), x_gauss)
            (;
                label = row.label,
                nll_bc_ns = format_time(row.nll_bc_ns),
                nll_direct_ns = row.nll_direct_ns === missing ? missing : format_time(row.nll_direct_ns),
                nll_ratio = format_ratio(row.nll_ratio),
            )
        end,
        begin
            row = benchmark_fit_step(make_prb_case(), x_prb)
            (;
                label = row.label,
                nll_bc_ns = format_time(row.nll_bc_ns),
                nll_direct_ns = row.nll_direct_ns === missing ? missing : format_time(row.nll_direct_ns),
                nll_ratio = format_ratio(row.nll_ratio),
            )
        end,
    ]

    println("BuildConstructors.jl overhead benchmark")
    println("Julia ", VERSION)
    println("BuildConstructors ", pkgversion(BuildConstructors))

    print_table(
        "build_model overhead (median, nanoseconds)",
        build_rows,
        (:label, :build_bc_ns, :build_direct_ns, :build_ratio),
    )

    print_table(
        "Metadata collectors (median, nanoseconds; setup-time only)",
        metadata_rows,
        (:label, :running_values, :running_names, :parameter_metadata),
    )

    print_table(
        "One fit evaluation: build + 1000× likelihood (median, nanoseconds)",
        fit_rows,
        (:label, :nll_bc_ns, :nll_direct_ns, :nll_ratio),
    )

    mem_rows = map(c -> begin
        row = benchmark_build(c)
        (;
            label = row.label,
            constructor = format_bytes(row.constructor_bytes),
            model = format_bytes(row.model_bytes),
            delta = format_bytes(row.constructor_bytes - row.model_bytes),
        )
    end, cases)
    print_table(
        "Approximate heap footprint (Base.summarysize)",
        mem_rows,
        (:label, :constructor, :model, :delta),
    )

    println()
    println("Notes")
    println("- Ratios > 1 mean BuildConstructors is slower than the hand-written baseline.")
    println("- Metadata collectors are intended for setup, not per-iteration use.")
    println("- The constructor tree is persistent state; built models are usually ephemeral.")
    println("- PRB JSON case has no hand-written baseline; compare build_model time only.")
end

main()
