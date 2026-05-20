struct ExtendedMixtureModel{
    VF<:VariateForm,
    VS<:ValueSupport,
    C<:Distribution,
    RT<:Real,
} <: Distribution{VF,VS}
    components::Vector{C}
    yields::Vector{RT}

    function ExtendedMixtureModel{VF,VS,C,RT}(cs::Vector{C}, ys::Vector{RT}) where {VF,VS,C,RT}
        length(cs) == length(ys) ||
            throw(ArgumentError("ExtendedMixtureModel: $(length(cs)) components vs $(length(ys)) yields"))
        new{VF,VS,C,RT}(cs, ys)
    end
end

function ExtendedMixtureModel(cs::Vector{C}, ys::AbstractVector{<:Real}) where {C<:Distribution}
    length(cs) == length(ys) || throw(ArgumentError("ExtendedMixtureModel: length mismatch"))
    any(<(zero(eltype(ys))), ys) && throw(ArgumentError("ExtendedMixtureModel: yields must be non-negative"))
    VF = Distributions.variate_form(C)
    VS = Distributions.value_support(C)
    RT = promote_type(Float64, eltype(ys))
    return ExtendedMixtureModel{VF,VS,C,RT}(cs, Vector{RT}(ys))
end

Distributions.ncomponents(d::ExtendedMixtureModel) = length(d.components)
Distributions.components(d::ExtendedMixtureModel) = d.components
Distributions.component(d::ExtendedMixtureModel, k::Int) = d.components[k]
Distributions.component_type(d::ExtendedMixtureModel{VF,VS,C}) where {VF,VS,C} = C

yields(d::ExtendedMixtureModel) = d.yields
total_yield(d::ExtendedMixtureModel) = sum(yields(d))

function (::Type{MixtureModel})(d::ExtendedMixtureModel)
    total = total_yield(d)
    total > 0 || throw(ArgumentError("MixtureModel(::ExtendedMixtureModel): total yield must be positive"))
    return MixtureModel(components(d), yields(d) ./ total)
end

function Distributions.pdf(d::ExtendedMixtureModel{Multivariate}, x::AbstractVector{<:Real})
    return sum(yi * pdf(component(d, i), x) for (i, yi) in enumerate(yields(d)) if !iszero(yi))
end

function Distributions.logpdf(d::ExtendedMixtureModel{Multivariate}, x::AbstractVector{<:Real})
    density = pdf(d, x)
    return density <= 0 ? -Inf : log(density)
end

Base.length(d::ExtendedMixtureModel{Multivariate}) = length(d.components[1])
