# load_model_from_json.jl

using JSON, OrderedCollections

function convert_database_to_prb(db, phys, res, bg)
    # pick components
    model_p = db["physical"][phys]
    model_r = db["resolution"][res]
    model_b = db["background"][bg]

    # Fit range is the "support" stored in the database top-level
    fit_range = db["support"]  # expect a 2-element vector [low, high]

    # Set the background support = fit range
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

function load_prb_model_from_json(filename, phys, res, bg)
    db = JSON.parsefile(filename; dicttype = OrderedDict)
    converted = convert_database_to_prb(db, phys, res, bg)
    constructor, starting_parameters = deserialize(ConstructorOfPRBModel, converted)
    return constructor, starting_parameters
end
