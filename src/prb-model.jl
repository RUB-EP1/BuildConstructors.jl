using JSON

@with_parameters(
    PRBModel;
    fs::P,
    model_p,
    model_r,
    model_b,
    support::Tuple{Float64,Float64},
    grid_size::Int,
    begin
        p = build_model(_.model_p, pars)
        r = build_model(_.model_r, pars)
        b = build_model(_.model_b, pars)
        r_conv_p = truncated(fft_convolve(r, p; gridsize = _.grid_size), _.support[1], _.support[2])
        MixtureModel([r_conv_p, b], [fs, 1-fs])
    end
)

register!(ConstructorOfPRBModel)

serialize(c::ConstructorOfPRBModel; pars) = LittleDict(
    "type" => "ConstructorOfPRBModel",
    "model_p" => serialize(c.model_p; pars),
    "model_r" => serialize(c.model_r; pars),
    "model_b" => serialize(c.model_b; pars),
    "description_of_fs" => serialize(c.description_of_fs; pars),
    "support" => c.support,
    "grid_size" => c.grid_size,
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

"""
    convert_database_to_prb(db, phys, res, bg)

Convert a database-style PRB entry into the serialized
`ConstructorOfPRBModel` shape expected by `deserialize`.

This helper belongs to the physical-resolution-background example workflow. It
is not required for defining ordinary constructor wrappers.
"""
function convert_database_to_prb(db, phys, res, bg)
    model_p = db["physical"][phys]
    model_r = db["resolution"][res]
    model_b = db["background"][bg]

    fit_range = db["support"]
    model_b["support"] = fit_range

    phys_support = fit_range .+ model_r["support"]
    model_p["support"] = phys_support

    return OrderedDict(
        "type" => "ConstructorOfPRBModel",
        "model_p" => model_p,
        "model_r" => model_r,
        "model_b" => model_b,
        "description_of_fs" => db["description_of_fs"],
        "support" => fit_range,
        "grid_size" => db["grid_size"],
    )
end

"""
    load_prb_model_from_json(filename, phys, res, bg) -> constructor, starting_parameters

Load a physical-resolution-background constructor from a JSON database file.

The returned constructor can be passed to `build_model(constructor,
starting_parameters)` or updated with another parameter container. This function
is a convenience for the bundled PRB workflow, not part of the core constructor
pattern.
"""
function load_prb_model_from_json(filename, phys, res, bg)
    db = JSON.parsefile(filename; dicttype = OrderedDict)
    converted = convert_database_to_prb(db, phys, res, bg)
    constructor, starting_parameters = deserialize(ConstructorOfPRBModel, converted)
    return constructor, starting_parameters
end
