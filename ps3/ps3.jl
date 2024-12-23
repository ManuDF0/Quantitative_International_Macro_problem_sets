include("deuda.jl")

using Plots, LaTeXStrings

#mkdir("./output")

dd = NoDefault()
vfi!(dd)

plot(dd.gb[:, 1], dd.gc[:, 1], label="y = $(round(dd.ygrid[1], digits=2))")
for i in 2:10
    plot!(dd.gb[:, i], dd.gc[:, i], label="y = $(round(dd.ygrid[i], digits=2))")
end
xlabel!("Deuda")
ylabel!("Consumo")
savefig("./output/consumo_deuda_ingreso.png")

plot(dd.gb[:, 1], dd.gc[:, 1]./dd.ygrid[1], label="y = $(round(dd.ygrid[1], digits=2))")
for i in 2:10
    plot!(dd.gb[:, i], dd.gc[:, i]./dd.ygrid[i], label="y = $(round(dd.ygrid[i], digits=2))")
end
xlabel!("Deuda")
ylabel!("Consumo")
savefig("./output/porcion_consumo_deuda_ingreso.png")

x = range(0, dd.pars[:bmax], Int(dd.pars[:Nb]))

contour(x, dd.ygrid, dd.gc',
    xlabel = "Deuda",
    ylabel = "y",
    colorbar = false,
    clabels = true,
    levels = 10
)
savefig("./output/curvas_nivel_consumo.png")

function comparative_statics(dd::NoDefault; Nq = 10)
    beta = dd.pars[:β]
    Q = range(beta, 1, Nq)
    
    p = plot()
    for x in Q
        r_new = 1/x - 1
        dd = NoDefault(r = r_new)
        vfi!(dd)
        p = plot!(p, dd.ygrid, dd.gc[1,:], label="q = $(round(x, digits=2))")
    end
    return p
end

p = comparative_statics(dd)
xlabel!("Ingreso")
ylabel!("Consumo")
savefig(p, "./output/estatica_q.png")

function comparative_statics(Nσ = 10)
    Q = range(0.01, 0.05, Nσ)
    
    p = plot()
    for x in Q
        dd = NoDefault(σy = x)
        vfi!(dd)
        p = plot!(p, dd.ygrid, dd.gc[1,:], label="σy = $(round(x, digits=2))")
    end
    xlabel!("Ingreso")
    ylabel!("Consumo")
    return p
end

p = comparative_statics()
savefig(p, "./output/estatica_sigma.png")


include("deuda.jl")
dd = NoDefault()
vfi!(dd)

p = plot(dd.gb[:, 1], dd.gc[:, 1]./dd.ygrid[1], label="y = $(round(dd.ygrid[1], digits=2)), θ = 0")
plot!(p, dd.gb[:, 21], dd.gc[:, 21]./dd.ygrid[21], label="y = $(round(dd.ygrid[21], digits=2)), θ = 0")
function eval_value(jb, jy, bpv, itp_q, itp_v, θ, dd::Deuda)
    β = dd.pars[:β]
    bv, yv = dd.bgrid[jb], dd.ygrid[jy]

    qv = debtprice(dd, bpv, yv, itp_q)

    cv = budget_constraint(bpv, bv, yv, qv, dd)

    ut = u(cv, dd)
    Ev = 0.0
    if θ > 1e-10
        for (jyp, ypv) in enumerate(dd.ygrid)
            prob = dd.Py[jy, jyp]
            Ev += prob*exp(-θ*itp_v(bpv, ypv))
        end
        Tv = -1/θ*log(Ev)
        v = ut + β * Tv
    else
        for (jyp, ypv) in enumerate(dd.ygrid)
            prob = dd.Py[jy, jyp]
            Ev += prob * itp_v(bpv, ypv)
        end
        v = ut + β * Ev
    end
    return v, cv
end

function opt_value(jb, jy, itp_q, itp_v, dd::Deuda)
    b_min, b_max = extrema(dd.bgrid)

    obj_f(bpv) = eval_value(jb, jy, bpv, itp_q, itp_v, dd)[1]

    res = Optim.maximize(obj_f, b_min, b_max)

    b_star = Optim.maximizer(res)

    vp, c_star = eval_value(jb, jy, b_star, itp_q, itp_v, 0.8, dd)
    return vp, c_star, b_star
end

dd = NoDefault()
vfi!(dd)

plot!(p, dd.gb[:, 1], dd.gc[:, 1]./dd.ygrid[1], label="y = $(round(dd.ygrid[1], digits=2)), θ > 0")
plot!(p, dd.gb[:, 21], dd.gc[:, 21]./dd.ygrid[21], label="y = $(round(dd.ygrid[21], digits=2)), θ > 0")
xlabel!("Deuda")
ylabel!("Consumo")
savefig(p, "./output/robustness.png")

include("simulador.jl")
bvec_all = []
c_y_vec = []
for _ in 1:1000
    bvec, yvec, cvec = simul(dd)
    append!(bvec_all, mean(bvec))
    append!(c_y_vec, mean(cvec./yvec))
end
hist = histogram(bvec_all, bins = 100, xlabel = "Deuda Promedio", ylabel = "Frecuencia", label = "θ > 0")
hist2 = histogram(c_y_vec, bins = 100, xlabel = "Promedio de la Propensión Promedio al Consumo", ylabel = "Frecuencia", label = "θ > 0")

include("deuda.jl")
dd = NoDefault()
vfi!(dd)
bvec_all = []
c_y_vec = []
for _ in 1:1000
    bvec, yvec, cvec = simul(dd)
    append!(bvec_all, mean(bvec))
    append!(c_y_vec, mean(cvec./yvec))
end
histogram!(hist, bvec_all, bins = 100, xlabel = "Deuda Promedio", ylabel = "Frecuencia", alpha = 0.7, label = "θ = 0")
histogram!(hist2, c_y_vec, bins = 100, xlabel = "Promedio de la Propensión Promedio al Consumo", ylabel = "Frecuencia", alpha = 0.5, label = "θ = 0")
savefig(hist, "./output/histograma_deuda.png")
savefig(hist2, "./output/histograma_prop_consumo.png")

include("arellano.jl")

ar = Arellano()
mpe!(ar)

contour(ar.bgrid, ar.ygrid, ar.prob',
    xlabel = "Deuda",
    ylabel = "Ingreso",
    colorbar = false,
    clabels = true,
    levels = 10
)
savefig("./output/default_esperado.png")

function b_star(ar::Arellano; Nβ = 3, costo = false, NΔ = 3)
    beta = ar.pars[:β]
    Q = range(beta, 0.99, Nβ)
    b_star = zeros(length(ar.ygrid))

    p = plot(size = (800, 600))
    p2 = plot(layout = (3, 1), size = (800, 600))
    if costo 
        ar = Arellano(T = Lin)
        mpe!(ar)
        delta = ar.pars[:Δ]
        Z = range(0.02, delta, NΔ)
        for (i, x) in enumerate(Z)
            ar = Arellano(T = Lin, Δ = x)
            mpe!(ar)
            for (jy, y) in enumerate(ar.ygrid)
                jb = findfirst(x -> x >= 0.5, ar.prob[:, jy])
                b_star[jy] = isnothing(jb) ? NaN : ar.bgrid[jb]
            end
            plot!(p, ar.ygrid, b_star, label = "Δ = $(x)")
            constant_vD = fill(ar.vD[10], length(ar.bgrid))
            plot!(p2[i], ar.bgrid, constant_vD, label = "VD, Δ = $(x)")
            plot!(p2[i], ar.bgrid, ar.vR[:, 10], label = "VR, Δ = $(x)")
        end
    else
        for (i, x) in enumerate(Q)
            ar = Arellano(β = x)
            mpe!(ar)
            for (jy, y) in enumerate(ar.ygrid)
                jb = findfirst(x -> x >= 0.5, ar.prob[:, jy])
                b_star[jy] = ar.bgrid[jb]
            end
            plot!(p, ar.ygrid, b_star, label = "β = $(x)")
            constant_vD = fill(ar.vD[10], length(ar.bgrid))
            plot!(p2[i], ar.bgrid, constant_vD, label = "VD, β = $(x)")
            plot!(p2[i], ar.bgrid, ar.vR[:, 10], label = "VR, β = $(x)")
        end
    end
    xlabel!(p, "Ingreso")
    ylabel!(p, "Nivel de deuda para el cual es más probable defaultear")
    xlabel!(p2[3], "Deuda")
    ylabel!(p2[2], "Valor")
    return p, p2
end

p, p2 = b_star(ar)
savefig(p, "./output/b_mas_probable_beta.png")
savefig(p2, "./output/valor_betas.png")

p, p2 = b_star(ar, costo = true)
savefig(p, "./output/b_mas_probable_Delta.png")
savefig(p2, "./output/valor_Deltas.png")

function shock_prefs(; Nχ = 3)
    Q = range(0.0001, 0.1, Nχ)
    
    p = plot(layout = (1, 3), size = (1000, 500))
    for (i, x) in enumerate(Q)
        ar = Arellano(χ = x)
        mpe!(ar)
        
        plot!(p[i], ar.bgrid, ar.v[:, 10], label = "V, χ = $(x)", xlims = (0, 0.3), ylims = (-0.4,0.3))
        
        constant_vD = fill(ar.vD[10], length(ar.bgrid))
        plot!(p[i], ar.bgrid, constant_vD, label = "VD, χ = $(x)", xlims = (0, 0.3), ylims = (-0.4,0.3))
        
        plot!(p[i], ar.bgrid, ar.vR[:, 10], label = "VR, χ = $(x)", xlims = (0, 0.3), ylims = (-0.4,0.3))
    end

    xlabel!(p[2], "Deuda")
    ylabel!(p[1], "Valor")
    return p
end

p = shock_prefs()
savefig(p, "./output/funciones_valor.png")

function q_iter!(new_q, dd::Arellano)
	r = dd.pars[:r]

	for jbp in eachindex(dd.bgrid), jy in eachindex(dd.ygrid)
		Eq = 0.0
		for jyp in eachindex(dd.ygrid)
            prob = dd.Py[jy, jyp]
			Eq += prob
		end
		new_q[jbp, jy]  = Eq / (1+r)
	end
end

ar = Arellano()
mpe!(ar)

contour(ar.bgrid, ar.ygrid, ar.prob',
    xlabel = "Deuda",
    ylabel = "Ingreso",
    legend = true,
    colorbar = false,
    clabels = true,
    levels = 5
)

include("arellano.jl")
ar = Arellano()
mpe!(ar)

contour!(ar.bgrid, ar.ygrid, ar.prob', 
    color = cgrad([:green, :red]),
    legend = true,
    colorbar = false,
    clabels = true,
    levels = 5
)
plot!(label = ["Precios favorables" "RATEX"])

savefig("./output/region_default_repago_superpuesto.png")