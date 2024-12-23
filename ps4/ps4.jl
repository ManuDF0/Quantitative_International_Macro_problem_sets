include("SGU.jl")
#mkdir("./output/")

using Plots, LaTeXStrings

sw_h = SOEwr()
comp_eqm!(sw_h)

p = plot(sw_h.zgrid, sw_h.Y[1, :], label = "wbar = $(sw_h.pars[:wbar])")

sw_l = SOEwr(wbar = 0)
comp_eqm!(sw_l)

plot!(p, sw_l.zgrid, sw_l.Y[1, :], label = "wbar = $(sw_l.pars[:wbar])")
xlabel!(L"$z$")
ylabel!(L"$y(z, A)$")
savefig(p, "./output/y_wbarh_wbarl.png")

function simul_stats(sw::SOEwr)
	SR = zeros(1000)
	COV = zeros(1000)
	for i in range(1, 1000)
		path = simul(sw, T = 1000)
		C = path[:C]
		Y = path[:Y]
		CA = path[:CA]
		σ_c = std(C)
		σ_y = std(Y)
		SR[i] = σ_c / σ_y
		COV[i] = cov(Y, CA)
	end
	return SR, COV
end

path_h = simul(sw_h, T = 1000)
C = path_h[:C]
Y = path_h[:Y]
p2 = plot(C, label= L"$c^h(t)$")
xlabel!(L"$t$")
p3 = plot(Y, label= L"$y^h(t)$")
xlabel!(L"$t$")

path_l = simul(sw_l, T = 1000)
C = path_l[:C]
Y = path_l[:Y]

plot!(p2, C, label= L"$c^l(t)$")
plot!(p3, Y, label= L"$y^l(t)$")
savefig(p2, "./output/volatilidad_consumo.png")
savefig(p3, "./output/volatilidad_ingreso.png")

SR_h, COV_h = simul_stats(sw_h)
SR_l, COV_l = simul_stats(sw_l)

h_sr = histogram(SR_h, label = L"\frac{\sigma_{c^h}}{\sigma_{y^h}}")
histogram!(h_sr, SR_l, label = L"\frac{\sigma_{c^l}}{\sigma_{y^l}}", alpha = 0.5)
savefig(h_sr, "./output/histograma_volatilidad_relativa.png")

h_cov = histogram(COV_h, label = L"Cov(y^h, CA^h)")
histogram!(COV_l, label = L"Cov(y^h, CA^h)", alpha = 0.5)
savefig(h_cov, "./output/covarianzas.png")

D_h = zeros(1000)
D_l = zeros(1000)
for i in range(1, 1000)
    path_h = simul(sw_h, T = 10000)
    path_l = simul(sw_l, T = 10000)

    D_h[i] = path_h[:A][10000]
    D_l[i] = path_l[:A][10000]
end
h = histogram(D_h, bins = 100, ylims = (0, 100), label = L"$a^h(t)$")
histogram!(h, D_l, bins = 100, label = L"$a^l(t)$", alpha = 0.5)
ylabel!("Frecuencia")
xlabel!("Activos")
savefig(h, "./output/distrib_ergodica.png")

include("SGU.jl")
sw_base = SOEwr()
comp_eqm!(sw_base)

p4 = plot(sw_base.agrid, sw_base.ga[:, 20, 5], label="z = $(round(sw_base.zgrid[5], digits = 2)), κ = 0")
p5 = plot(sw_base.agrid, sw_base.ga[:, 20, 20], label="z = $(round(sw_base.zgrid[20], digits = 2)), κ = 0")

function optim_value(av, yv, Apv, pz, pCv, itp_v, sw::SOE)
	κ = 0.3
	obj_f(x) = eval_value(x, av, yv, Apv, pz, pCv, itp_v, sw)
	amin = max(-κ*pCv*yv, extrema(sw.agrid)[1])
	amax = extrema(sw.agrid)[2]

	res = Optim.maximize(obj_f, amin, amax)

	apv = Optim.maximizer(res)
	v  = Optim.maximum(res)

	c = budget_constraint(apv, av, yv, sw.pars[:r], pCv)

	return v, apv, c
end

sw_mod = SOEwr()
comp_eqm!(sw_mod)

plot!(p4, sw_mod.agrid, sw_mod.ga[:, 20, 5], label="z = $(round(sw_mod.zgrid[5], digits = 2)), κ = 0.3")
xlabel!(L"$a_t$")
ylabel!(L"$a_{t+1}(a_t, A_t, z_t)$")
plot!(p5, sw_mod.agrid, sw_mod.ga[:, 20, 20], label="z = $(round(sw_mod.zgrid[20], digits = 2)), κ = 0.3")
xlabel!(L"$a_t$")
ylabel!(L"$a_{t+1}(a_t, A_t, z_t)$")

savefig(p4, "./output/ahorro_lowprod.png")
savefig(p5, "./output/ahorro_highprod.png")

p = contour(
    sw_base.agrid,
    sw_base.zgrid,
    sw_base.ga[:, 20, :]',
    xlabel = L"a_t",
    ylabel = L"z_t",
    clabels = true,
    colorbar = false,
    label = "Modelo Base",
    linecolor = cgrad([:blue, :green])
)
contour!(
    p,
    sw_mod.agrid,
    sw_mod.zgrid,
    sw_mod.ga[:, 20, :]',
    clabels = true,
    colorbar = false,
    linecolor = cgrad([:red, :orange]),
    label = "Restringido",
    legend = true
)
savefig("./output/curva_nivel_ahorro.png")

include("SGU.jl")
path_base = simul(sw_base, T = 1000)
A = path_base[:A]

histogram(A, ylims = (0, 100), bins = 100, label = "Modelo Base")

function iter_simul!(tt, path, itp_gc, itp_ga, itp_w, itp_Y, itp_pN, At, zt, sw::SOE)
	w  = itp_w(At, zt)
	Y  = itp_Y(At, zt)
	pN = itp_pN(At, zt)
	pC = price_index(pN, sw)

	C = itp_gc(At, At, zt)

	cT = C * sw.pars[:ϖT] * (pC)^sw.pars[:η]
	cN = C * sw.pars[:ϖN] * (pC/pN)^sw.pars[:η]

	CA = Y - pC * C

	path[:CA][tt] = CA
	path[:pN][tt] = pN
	path[:w][tt]  = w
	path[:Y][tt]  = Y
	path[:C][tt]  = C
	path[:A][tt]  = At
	path[:z][tt]  = zt

    κ = 0.3

	A_new = itp_ga(At, At, zt)
    if A_new < -κ*pC*Y
        A_new = -κ*pC*Y
    else
        A_new = A_new
    end
	amin, amax = extrema(sw.agrid)
	A_new = max(amin, min(amax, A_new))

	ρz, σz = 0.945, 0.025
	ϵ_new = rand(Normal(0,1))
	z_new = exp(ρz * log(zt) + σz * ϵ_new)

	zmin, zmax = extrema(sw.zgrid)
	z_new = max(zmin, min(zmax, z_new))	

	return A_new, z_new
end
path_mod = simul(sw_mod, T = 1000)
A = path_mod[:A]

histogram!(A, alpha = 0.5, label = "Modelo Restringido", bins = 100)
xlabel!("Activos")
ylabel!("Frecuencia")

savefig("./output/activos_libres_restringidos")

path_mod = simul(sw_mod, T = 10000)
A = path_mod[:A]
Y = path_mod[:Y]
κ = 0.3
tol = 1e-2 
ind = zeros(length(A))
prev = false
for t in eachindex(A)
	y = Y[t]
	a = A[t]
	if abs(a + κ*y) <= tol && prev == false
		ind[t] = t
		prev = true
	else
		ind[t] = 0
		prev = false
	end
end

function active(path::Dict{Symbol, Vector{Float64}}, ind::Vector{Float64})
	Y = path[:Y]
	C = path[:C]
	CA = path[:CA]
	A = path[:A]

	p = plot(size = (700, 450), xlabel=L"t", ylabel=L"y_t")
	p2 = plot(size = (700, 450), xlabel=L"t", ylabel=L"CA_t")
	p3 = plot(size = (700, 450), xlabel=L"t", ylabel=L"A_t")
	p4 = plot(size = (700, 450), xlabel=L"t", ylabel=L"c_t")
	for t in eachindex(ind)
		if ind[t] != 0
			start_idx = max(1, t - 5)
			end_idx = min(length(Y), t + 5)
			Y_values = Y[start_idx:end_idx]
			C_values = C[start_idx:end_idx]
			CA_values = CA[start_idx:end_idx]
			A_values = A[start_idx:end_idx]
			time_shifted = (start_idx:end_idx) .- t
			plot!(p, time_shifted, Y_values, legend = false)
			plot!(p4, time_shifted, C_values, legend = false)
			plot!(p2, time_shifted, CA_values, legend = false)
			plot!(p3, time_shifted, A_values, legend = false)
		end
	end
	return p, p2, p3, p4
end

p, p2, p3, p4 = active(path_mod, ind)
for plot in [p, p2, p3, p4]
	display(plot)
end

savefig(p, "./output/active_y.png")
savefig(p2, "./output/active_ca.png")
savefig(p3, "./output/active_a.png")
savefig(p4, "./output/active_c.png")