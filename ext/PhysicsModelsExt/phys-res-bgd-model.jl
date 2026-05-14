@with_parameters(
    PRBModel;
    fs::P,
    model_p,
    model_r,
    model_b,
    support::Tuple{Float64,Float64},
    grid_size::Int,
    other_pars -> begin
        p = build_model(model_p, other_pars)
        r = build_model(model_r, other_pars)
        b = build_model(model_b, other_pars)
        r_conv_p = truncated(fft_convolve(r, p; gridsize = grid_size), support[1], support[2])
        MixtureModel([r_conv_p, b], [fs, 1-fs])
    end
)
