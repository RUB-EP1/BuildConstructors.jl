@with_parameters(
    PRBModel;
    fs::P,
    model_p,
    model_r,
    model_b,
    support::Tuple{Float64,Float64},
    grid_size::Int,
    pars -> begin
        p = build_model(model_p, pars)
        r = build_model(model_r, pars)
        b = build_model(model_b, pars)
        r_conv_p = truncated(fft_convolve(r, p; gridsize = grid_size), support[1], support[2])
        MixtureModel([r_conv_p, b], [fs, 1-fs])
    end
)
