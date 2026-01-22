# parameter types
register!(Fixed)
register!(Running)
register!(FlexibleParameter)
register!(AdvancedParameter)

# thin wrappers of primitives
register!(ConstructorOfBW)
register!(ConstructorOfBraaten)
register!(ConstructorOfCBpSECH)
register!(ConstructorOfGaussian)
register!(ConstructorOfPol1)
register!(ConstructorOfPol2)

# complex model
register!(ConstructorOfPRBModel)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::Fixed; pars) = LittleDict("type" => "Fixed", "value" => c.value)
serialize(c::Running; pars) =
    LittleDict("type" => "Running", "name" => c.name, "starting_value" => value(c; pars))

function deserialize(::Type{<:Fixed}, all_fields)
    value = all_fields["value"]
    Fixed(value), NamedTuple()
end

function deserialize(::Type{<:Running}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    Running(name), NamedTuple{(Symbol(name),)}((starting_value,))
end

serialize(c::FlexibleParameter; pars) = LittleDict(
    "type" => "FlexibleParameter",
    "name" => c.name,
    "starting_value" => value(c; pars),
    "fixed" => c.fixed,
)

function deserialize(::Type{<:FlexibleParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    fixed = get(all_fields, "fixed", false)
    FlexibleParameter(name, starting_value, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end

serialize(c::AdvancedParameter; pars) = LittleDict(
    "type" => "AdvancedParameter",
    "name" => c.name,
    "starting_value" => value(c; pars),
    "boundaries" => c.boundaries,
    "uncertainty" => c.uncertainty,
    "fixed" => c.fixed,
)

function deserialize(::Type{<:AdvancedParameter}, all_fields)
    name = all_fields["name"]
    starting_value = all_fields["starting_value"]
    boundaries = Tuple(all_fields["boundaries"])
    uncertainty = all_fields["uncertainty"]
    fixed = get(all_fields, "fixed", false)
    AdvancedParameter(name, starting_value, boundaries, uncertainty, fixed),
    NamedTuple{(Symbol(name),)}((starting_value,))
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfGaussian; pars) = LittleDict(
    "type" => "ConstructorOfGaussian",
    "description_of_μ" => serialize(c.description_of_μ; pars),
    "description_of_σ" => serialize(c.description_of_σ; pars),
    "support" => c.support,
)




function deserialize(::Type{<:ConstructorOfGaussian}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_μ_dict = all_fields["description_of_μ"]
    type_μ = _type_from_string(description_of_μ_dict["type"])
    description_of_μ, appendix_μ = deserialize(type_μ, description_of_μ_dict)
    appendix = merge(appendix, appendix_μ)
    # 
    description_of_σ_dict = all_fields["description_of_σ"]
    type_σ = _type_from_string(description_of_σ_dict["type"])
    description_of_σ, appendix_σ = deserialize(type_σ, description_of_σ_dict)
    appendix = merge(appendix, appendix_σ)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfGaussian(description_of_μ, description_of_σ, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfPol1; pars) = LittleDict(
    "type" => "ConstructorOfPol1",
    "description_of_c1C" => serialize(c.description_of_c1C; pars),
    "support" => c.support,
)


function deserialize(::Type{<:ConstructorOfPol1}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_c1C_dict = all_fields["description_of_c1C"]
    type_c1C = _type_from_string(description_of_c1C_dict["type"])
    description_of_c1C, appendix_c1C = deserialize(type_c1C, description_of_c1C_dict)
    appendix = merge(appendix, appendix_c1C)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfPol1(description_of_c1C, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfPol2; pars) = LittleDict(
    "type" => "ConstructorOfPol2",
    "description_of_c1C" => serialize(c.description_of_c1C; pars),
    "description_of_c2C" => serialize(c.description_of_c2C; pars),
    "support" => c.support,
)

function deserialize(::Type{<:ConstructorOfPol2}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_c1C_dict = all_fields["description_of_c1C"]
    type_c1C = _type_from_string(description_of_c1C_dict["type"])
    description_of_c1C, appendix_c1C = deserialize(type_c1C, description_of_c1C_dict)
    appendix = merge(appendix, appendix_c1C)
    # 
    description_of_c2C_dict = all_fields["description_of_c2C"]
    type_c2C = _type_from_string(description_of_c2C_dict["type"])
    description_of_c2C, appendix_c2C = deserialize(type_c2C, description_of_c2C_dict)
    appendix = merge(appendix, appendix_c2C)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfPol2(description_of_c1C, description_of_c2C, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfCBpSECH; pars) = LittleDict(
    "type" => "ConstructorOfCBpSECH",
    "description_of_σ1" => serialize(c.description_of_σ1; pars),
    "description_of_c0" => serialize(c.description_of_c0; pars),
    "description_of_c1" => serialize(c.description_of_c1; pars),
    "description_of_c2" => serialize(c.description_of_c2; pars),
    "description_of_n" => serialize(c.description_of_n; pars),
    "description_of_s" => serialize(c.description_of_s; pars),
    "description_of_fr1" => serialize(c.description_of_fr1; pars),
    "description_of_w" => serialize(c.description_of_w; pars),
    "support" => c.support,
)

function deserialize(::Type{<:ConstructorOfCBpSECH}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_σ1_dict = all_fields["description_of_σ1"]
    type_σ1 = _type_from_string(description_of_σ1_dict["type"])
    description_of_σ1, appendix_σ1 = deserialize(type_σ1, description_of_σ1_dict)
    appendix = merge(appendix, appendix_σ1)
    # 
    description_of_c0_dict = all_fields["description_of_c0"]
    type_c0 = _type_from_string(description_of_c0_dict["type"])
    description_of_c0, appendix_c0 = deserialize(type_c0, description_of_c0_dict)
    appendix = merge(appendix, appendix_c0)
    # 
    description_of_c1_dict = all_fields["description_of_c1"]
    type_c1 = _type_from_string(description_of_c1_dict["type"])
    description_of_c1, appendix_c1 = deserialize(type_c1, description_of_c1_dict)
    appendix = merge(appendix, appendix_c1)
    # 
    description_of_c2_dict = all_fields["description_of_c2"]
    type_c2 = _type_from_string(description_of_c2_dict["type"])
    description_of_c2, appendix_c2 = deserialize(type_c2, description_of_c2_dict)
    appendix = merge(appendix, appendix_c2)
    # 
    description_of_n_dict = all_fields["description_of_n"]
    type_n = _type_from_string(description_of_n_dict["type"])
    description_of_n, appendix_n = deserialize(type_n, description_of_n_dict)
    appendix = merge(appendix, appendix_n)
    # 
    description_of_s_dict = all_fields["description_of_s"]
    type_s = _type_from_string(description_of_s_dict["type"])
    description_of_s, appendix_s = deserialize(type_s, description_of_s_dict)
    appendix = merge(appendix, appendix_s)
    # 
    description_of_fr1_dict = all_fields["description_of_fr1"]
    type_fr1 = _type_from_string(description_of_fr1_dict["type"])
    description_of_fr1, appendix_fr1 = deserialize(type_fr1, description_of_fr1_dict)
    appendix = merge(appendix, appendix_fr1)
    # 
    description_of_w_dict = all_fields["description_of_w"]
    type_w = _type_from_string(description_of_w_dict["type"])
    description_of_w, appendix_w = deserialize(type_w, description_of_w_dict)
    appendix = merge(appendix, appendix_w)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfCBpSECH(
        description_of_σ1,
        description_of_c0,
        description_of_c1,
        description_of_c2,
        description_of_n,
        description_of_s,
        description_of_fr1,
        description_of_w,
        support,
    ),
    appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfBraaten; pars) = LittleDict(
    "type" => "ConstructorOfBraaten",
    "description_of_γre" => serialize(c.description_of_γre; pars),
    "description_of_γim" => serialize(c.description_of_γim; pars),
    "support" => c.support,
)


function deserialize(::Type{<:ConstructorOfBW}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_m_dict = all_fields["description_of_m"]
    type_m = _type_from_string(description_of_m_dict["type"])
    description_of_m, appendix_m = deserialize(type_m, description_of_m_dict)
    appendix = merge(appendix, appendix_m)
    # 
    description_of_Γ_dict = all_fields["description_of_Γ"]
    type_Γ = _type_from_string(description_of_Γ_dict["type"])
    description_of_Γ, appendix_Γ = deserialize(type_Γ, description_of_Γ_dict)
    appendix = merge(appendix, appendix_Γ)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfBW(description_of_m, description_of_Γ, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfBW; pars) = LittleDict(
    "type" => "ConstructorOfBW",
    "description_of_m" => serialize(c.description_of_m; pars),
    "description_of_Γ" => serialize(c.description_of_Γ; pars),
    "support" => c.support,
)

function deserialize(::Type{<:ConstructorOfBraaten}, all_fields)
    appendix = NamedTuple()
    # 
    description_of_γre_dict = all_fields["description_of_γre"]
    type_γre = _type_from_string(description_of_γre_dict["type"])
    description_of_γre, appendix_γre = deserialize(type_γre, description_of_γre_dict)
    appendix = merge(appendix, appendix_γre)
    # 
    description_of_γim_dict = all_fields["description_of_γim"]
    type_γim = _type_from_string(description_of_γim_dict["type"])
    description_of_γim, appendix_γim = deserialize(type_γim, description_of_γim_dict)
    appendix = merge(appendix, appendix_γim)
    # 
    support = all_fields["support"] |> Tuple
    return ConstructorOfBraaten(description_of_γre, description_of_γim, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

serialize(c::ConstructorOfPRBModel; pars) = LittleDict(
    "type" => "ConstructorOfPRBModel",
    "model_p" => serialize(c.model_p; pars),
    "model_r" => serialize(c.model_r; pars),
    "model_b" => serialize(c.model_b; pars),
    "description_of_fs" => serialize(c.description_of_fs; pars),
    "support" => c.support,
    "gridsize" => c.gridsize,
)

function deserialize(::Type{<:ConstructorOfPRBModel}, all_fields)
    appendix = NamedTuple()


    description_of_p = all_fields["model_p"]
    type_p = _type_from_string(description_of_p["type"])
    model_p, appendix_p = deserialize(type_p, description_of_p)
    appendix = merge(appendix, appendix_p)

    description_of_r = all_fields["model_r"]
    type_r = _type_from_string(description_of_r["type"])
    model_r, appendix_r = deserialize(type_r, description_of_r)
    appendix = merge(appendix, appendix_r)

    description_of_b = all_fields["model_b"]
    type_b = _type_from_string(description_of_b["type"])
    model_b, appendix_b = deserialize(type_b, description_of_b)
    appendix = merge(appendix, appendix_b)

    description_of_fs = all_fields["description_of_fs"]
    type_fs = _type_from_string(description_of_fs["type"])
    description_of_fs, appendix_fs = deserialize(type_fs, description_of_fs)
    appendix = merge(appendix, appendix_fs)

    support = all_fields["support"] |> Tuple
    grid_size = Int(all_fields["grid_size"])
    ConstructorOfPRBModel(model_p, model_r, model_b, description_of_fs, support, grid_size), appendix
end
