using NumericalDistributions
using HadronicLineshapes
using BuildConstructors
using Distributions
using Plots

theme(:boxed)

# instructions how to use parameters in 
# building flexible models
@with_parameters(Gauss; μ::P, σ::P, begin Normal(μ, σ) end)
@with_parameters(NormalizeAbs2Abs2; D, support::Tuple{Float64,Float64},
    begin
        NumericallyIntegrable(e->abs2(build_model(D, pars)(e^2)), support)
    end)
@with_parameters(BW; m::P, Γ::P, begin BreitWigner(m, Γ) end)
@with_parameters(Cut; cModel, support::Tuple{Float64,Float64}, begin truncated(build_model(cModel, pars), support[1], support[2]) end)
@with_parameters(S; cModel, scale::P, begin build_model(cModel, pars) * scale end)
@with_parameters(Comb; 
    cModel1,
    cModel2, 
    weight::P,
    begin
        MixtureModel([build_model(cModel1, pars), build_model(cModel2, pars)], [weight, 1-weight])
    end
)


# Let's try how it works
c = ConstructorOfComb(
    ConstructorOfCut(
            ConstructorOfS(
                ConstructorOfGauss(Running("μ"), Fixed(1.0)),
                Running("scale"),
            ),
            (0.5, 2.5),
    ),
    ConstructorOfNormalizeAbs2Abs2(
        ConstructorOfBW(Running("m"), Fixed(0.1)),
        (0.5, 2.5)
    ),
    Running("weight"),
)

# let's see what parameters are running, if there are good default values
parameter_values(c)

# build a model and plot it
m = build_model(c, (μ = 1.2, scale = 0.7, m = 1.8718, weight = 0.5))
let
    plot(x->pdf(m,x), 0.5, 2.5)
    plot!(x->pdf(m.components[1],x) * m.prior.p[1], 0.5, 2.5)
    plot!(x->pdf(m.components[2],x) * m.prior.p[2], 0.5, 2.5)
end

