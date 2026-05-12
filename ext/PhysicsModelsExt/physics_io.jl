# Register optional physics constructors (serialization); loaded inside PhysicsModelsExt.

BuildConstructors.register!(ConstructorOfBW; type_name = "ConstructorOfBW")
BuildConstructors.register!(ConstructorOfBraaten; type_name = "ConstructorOfBraaten")
BuildConstructors.register!(ConstructorOfCBpSECH; type_name = "ConstructorOfCBpSECH")
BuildConstructors.register!(ConstructorOfGaussian; type_name = "ConstructorOfGaussian")
BuildConstructors.register!(ConstructorOfPol1; type_name = "ConstructorOfPol1")
BuildConstructors.register!(ConstructorOfPol2; type_name = "ConstructorOfPol2")
BuildConstructors.register!(ConstructorOfPRBModel; type_name = "ConstructorOfPRBModel")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfGaussian; pars)
    LittleDict(
        "type" => "ConstructorOfGaussian",
        "description_of_μ" => BuildConstructors.serialize(c.description_of_μ; pars),
        "description_of_σ" => BuildConstructors.serialize(c.description_of_σ; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfGaussian}, all_fields)
    appendix = NamedTuple()
    description_of_μ_dict = all_fields["description_of_μ"]
    type_μ = BuildConstructors._type_from_string(description_of_μ_dict["type"])
    description_of_μ, appendix_μ = BuildConstructors.deserialize(type_μ, description_of_μ_dict)
    appendix = merge(appendix, appendix_μ)

    description_of_σ_dict = all_fields["description_of_σ"]
    type_σ = BuildConstructors._type_from_string(description_of_σ_dict["type"])
    description_of_σ, appendix_σ = BuildConstructors.deserialize(type_σ, description_of_σ_dict)
    appendix = merge(appendix, appendix_σ)

    support = all_fields["support"] |> Tuple
    return ConstructorOfGaussian(description_of_μ, description_of_σ, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfPol1; pars)
    LittleDict(
        "type" => "ConstructorOfPol1",
        "description_of_c1C" => BuildConstructors.serialize(c.description_of_c1C; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfPol1}, all_fields)
    appendix = NamedTuple()

    description_of_c1C_dict = all_fields["description_of_c1C"]
    type_c1C = BuildConstructors._type_from_string(description_of_c1C_dict["type"])
    description_of_c1C, appendix_c1C =
        BuildConstructors.deserialize(type_c1C, description_of_c1C_dict)
    appendix = merge(appendix, appendix_c1C)

    support = all_fields["support"] |> Tuple
    return ConstructorOfPol1(description_of_c1C, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfPol2; pars)
    LittleDict(
        "type" => "ConstructorOfPol2",
        "description_of_c1C" => BuildConstructors.serialize(c.description_of_c1C; pars),
        "description_of_c2C" => BuildConstructors.serialize(c.description_of_c2C; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfPol2}, all_fields)
    appendix = NamedTuple()

    description_of_c1C_dict = all_fields["description_of_c1C"]
    type_c1C = BuildConstructors._type_from_string(description_of_c1C_dict["type"])
    description_of_c1C, appendix_c1C =
        BuildConstructors.deserialize(type_c1C, description_of_c1C_dict)
    appendix = merge(appendix, appendix_c1C)

    description_of_c2C_dict = all_fields["description_of_c2C"]
    type_c2C = BuildConstructors._type_from_string(description_of_c2C_dict["type"])
    description_of_c2C, appendix_c2C =
        BuildConstructors.deserialize(type_c2C, description_of_c2C_dict)
    appendix = merge(appendix, appendix_c2C)

    support = all_fields["support"] |> Tuple
    return ConstructorOfPol2(description_of_c1C, description_of_c2C, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfCBpSECH; pars)
    LittleDict(
        "type" => "ConstructorOfCBpSECH",
        "description_of_σ1" => BuildConstructors.serialize(c.description_of_σ1; pars),
        "description_of_c0" => BuildConstructors.serialize(c.description_of_c0; pars),
        "description_of_c1" => BuildConstructors.serialize(c.description_of_c1; pars),
        "description_of_c2" => BuildConstructors.serialize(c.description_of_c2; pars),
        "description_of_n" => BuildConstructors.serialize(c.description_of_n; pars),
        "description_of_s" => BuildConstructors.serialize(c.description_of_s; pars),
        "description_of_fr1" => BuildConstructors.serialize(c.description_of_fr1; pars),
        "description_of_w" => BuildConstructors.serialize(c.description_of_w; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfCBpSECH}, all_fields)
    appendix = NamedTuple()

    description_of_σ1_dict = all_fields["description_of_σ1"]
    type_σ1 = BuildConstructors._type_from_string(description_of_σ1_dict["type"])
    description_of_σ1, appendix_σ1 =
        BuildConstructors.deserialize(type_σ1, description_of_σ1_dict)
    appendix = merge(appendix, appendix_σ1)

    description_of_c0_dict = all_fields["description_of_c0"]
    type_c0 = BuildConstructors._type_from_string(description_of_c0_dict["type"])
    description_of_c0, appendix_c0 =
        BuildConstructors.deserialize(type_c0, description_of_c0_dict)
    appendix = merge(appendix, appendix_c0)

    description_of_c1_dict = all_fields["description_of_c1"]
    type_c1 = BuildConstructors._type_from_string(description_of_c1_dict["type"])
    description_of_c1, appendix_c1 =
        BuildConstructors.deserialize(type_c1, description_of_c1_dict)
    appendix = merge(appendix, appendix_c1)

    description_of_c2_dict = all_fields["description_of_c2"]
    type_c2 = BuildConstructors._type_from_string(description_of_c2_dict["type"])
    description_of_c2, appendix_c2 =
        BuildConstructors.deserialize(type_c2, description_of_c2_dict)
    appendix = merge(appendix, appendix_c2)

    description_of_n_dict = all_fields["description_of_n"]
    type_n = BuildConstructors._type_from_string(description_of_n_dict["type"])
    description_of_n, appendix_n = BuildConstructors.deserialize(type_n, description_of_n_dict)
    appendix = merge(appendix, appendix_n)

    description_of_s_dict = all_fields["description_of_s"]
    type_s = BuildConstructors._type_from_string(description_of_s_dict["type"])
    description_of_s, appendix_s = BuildConstructors.deserialize(type_s, description_of_s_dict)
    appendix = merge(appendix, appendix_s)

    description_of_fr1_dict = all_fields["description_of_fr1"]
    type_fr1 = BuildConstructors._type_from_string(description_of_fr1_dict["type"])
    description_of_fr1, appendix_fr1 =
        BuildConstructors.deserialize(type_fr1, description_of_fr1_dict)
    appendix = merge(appendix, appendix_fr1)

    description_of_w_dict = all_fields["description_of_w"]
    type_w = BuildConstructors._type_from_string(description_of_w_dict["type"])
    description_of_w, appendix_w = BuildConstructors.deserialize(type_w, description_of_w_dict)
    appendix = merge(appendix, appendix_w)

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

function BuildConstructors.serialize(c::ConstructorOfBraaten; pars)
    LittleDict(
        "type" => "ConstructorOfBraaten",
        "description_of_γre" => BuildConstructors.serialize(c.description_of_γre; pars),
        "description_of_γim" => BuildConstructors.serialize(c.description_of_γim; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfBraaten}, all_fields)
    appendix = NamedTuple()

    description_of_γre_dict = all_fields["description_of_γre"]
    type_γre = BuildConstructors._type_from_string(description_of_γre_dict["type"])
    description_of_γre, appendix_γre =
        BuildConstructors.deserialize(type_γre, description_of_γre_dict)
    appendix = merge(appendix, appendix_γre)

    description_of_γim_dict = all_fields["description_of_γim"]
    type_γim = BuildConstructors._type_from_string(description_of_γim_dict["type"])
    description_of_γim, appendix_γim =
        BuildConstructors.deserialize(type_γim, description_of_γim_dict)
    appendix = merge(appendix, appendix_γim)

    support = all_fields["support"] |> Tuple
    return ConstructorOfBraaten(description_of_γre, description_of_γim, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfBW; pars)
    LittleDict(
        "type" => "ConstructorOfBW",
        "description_of_m" => BuildConstructors.serialize(c.description_of_m; pars),
        "description_of_Γ" => BuildConstructors.serialize(c.description_of_Γ; pars),
        "support" => c.support,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfBW}, all_fields)
    appendix = NamedTuple()

    description_of_m_dict = all_fields["description_of_m"]
    type_m = BuildConstructors._type_from_string(description_of_m_dict["type"])
    description_of_m, appendix_m = BuildConstructors.deserialize(type_m, description_of_m_dict)
    appendix = merge(appendix, appendix_m)

    description_of_Γ_dict = all_fields["description_of_Γ"]
    type_Γ = BuildConstructors._type_from_string(description_of_Γ_dict["type"])
    description_of_Γ, appendix_Γ = BuildConstructors.deserialize(type_Γ, description_of_Γ_dict)
    appendix = merge(appendix, appendix_Γ)

    support = all_fields["support"] |> Tuple
    return ConstructorOfBW(description_of_m, description_of_Γ, support), appendix
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function BuildConstructors.serialize(c::ConstructorOfPRBModel; pars)
    LittleDict(
        "type" => "ConstructorOfPRBModel",
        "model_p" => BuildConstructors.serialize(c.model_p; pars),
        "model_r" => BuildConstructors.serialize(c.model_r; pars),
        "model_b" => BuildConstructors.serialize(c.model_b; pars),
        "description_of_fs" => BuildConstructors.serialize(c.description_of_fs; pars),
        "support" => c.support,
        "grid_size" => c.grid_size,
    )
end

function BuildConstructors.deserialize(::Type{<:ConstructorOfPRBModel}, all_fields)
    appendix = NamedTuple()

    description_of_p = all_fields["model_p"]
    type_p = BuildConstructors._type_from_string(description_of_p["type"])
    model_p, appendix_p = BuildConstructors.deserialize(type_p, description_of_p)
    appendix = merge(appendix, appendix_p)

    description_of_r = all_fields["model_r"]
    type_r = BuildConstructors._type_from_string(description_of_r["type"])
    model_r, appendix_r = BuildConstructors.deserialize(type_r, description_of_r)
    appendix = merge(appendix, appendix_r)

    description_of_b = all_fields["model_b"]
    type_b = BuildConstructors._type_from_string(description_of_b["type"])
    model_b, appendix_b = BuildConstructors.deserialize(type_b, description_of_b)
    appendix = merge(appendix, appendix_b)

    description_of_fs = all_fields["description_of_fs"]
    type_fs = BuildConstructors._type_from_string(description_of_fs["type"])
    description_of_fs, appendix_fs = BuildConstructors.deserialize(type_fs, description_of_fs)
    appendix = merge(appendix, appendix_fs)

    support = all_fields["support"] |> Tuple
    grid_size = Int(all_fields["grid_size"])
    ConstructorOfPRBModel(model_p, model_r, model_b, description_of_fs, support, grid_size),
    appendix
end
