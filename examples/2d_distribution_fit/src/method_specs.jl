function default_method_specs()
    return MethodSpec[
        MethodSpec("Optim.Fminbox(LBFGS())", () -> Fminbox(LBFGS()), true, "Bounded quasi-Newton baseline."),
        MethodSpec(
            "Optim.Fminbox(LBFGS(); descriptor steps)",
            () -> Fminbox(LBFGS()),
            true,
            :optim_descriptor_steps,
            "Bounded LBFGS with finite-difference steps from parameter uncertainties.",
        ),
        MethodSpec(
            "Optim.Fminbox(LBFGS(); Minuit metric)",
            () -> (method = LBFGS(m = 10, scaleinvH0 = false), tolerance = 0.01, errordef = 0.5),
            true,
            :optim_minuit_lbfgs,
            "Bounded LBFGS with descriptor finite-difference steps, descriptor-scaled preconditioning, and an EDM-style stopping proxy.",
        ),
        MethodSpec(
            "Optim.Fminbox(BFGS(); Minuit metric)",
            () -> (tolerance = 0.01, errordef = 0.5),
            true,
            :optim_minuit_bfgs,
            "Bounded full-memory BFGS with descriptor finite-difference steps, diagonal initial inverse Hessian, and an EDM callback.",
        ),
        MethodSpec("Optim.Fminbox(BFGS())", () -> Fminbox(BFGS()), true, "Bounded full-memory BFGS baseline."),
        MethodSpec("Optim.NelderMead()", () -> NelderMead(), false, "Unbounded derivative-free baseline; expected to expose invalid-region behavior."),
        MethodSpec("Optim.ParticleSwarm()", () -> ParticleSwarm(), false, "Derivative-free global-ish probe; useful mainly as a robustness contrast."),
        MethodSpec(
            "Minuit2.Migrad(strategy=1)",
            () -> (strategy = 1, tolerance = 0.01, hesse = false),
            true,
            :minuit,
            "Minuit migrad with bounds and descriptor step sizes.",
        ),
        MethodSpec(
            "Minuit2.Migrad(strategy=2)",
            () -> (strategy = 2, tolerance = 0.01, hesse = true),
            true,
            :minuit,
            "Minuit migrad with safer strategy, bounds, descriptor step sizes, and Hesse.",
        ),
    ]
end
