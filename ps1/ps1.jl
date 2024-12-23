include("mccall.jl")

using Distributions, LinearAlgebra, StatsBase, LaTeXStrings, Plots

# Punto 1: estática comparada
function comparative_statics(;bmin = 0.5, bmax=1.5, N=25, βmax = 0.99, βmin = 0.2, impaciencia = false)
    Z = range(βmin, βmax, N)
    B = range(bmin, bmax, N)
    V = similar(B)

    if impaciencia
        for (i, x) in enumerate(Z)
            mc = McCall(β=x, Nw = 1000)
            vfi!(mc)
            V[i] = mc.w_star
        end

        return V, Z
    else
        for (i, x) in enumerate(B)
            mc = McCall(b=x, Nw = 1000)
            vfi!(mc)
            V[i] = mc.w_star
        end
        return V, B    
    end
end

V, B = comparative_statics()

p1 = plot(B, V, label = L"w^*(b)")

savefig(p1, "./output/w_star(b).png")

V, Z = comparative_statics(impaciencia = true)

p2 = plot(Z, V, label = L"w^*(β)")

savefig(p2, "./output/w_star(beta).png")

# Punto 2: simulaciones
function tiempo_parada(mc::McCall; k = 10000)
    T = zeros(k)
    vfi!(mc)
    for i in eachindex(T)
        t = simul(mc, verbose = false)
        T[i] = t
    end
    return T
end

mc = McCall()
T = tiempo_parada(mc)

p3 = histogram(T, label = "Frecuencia")
savefig(p3, "./output/freq_t.png")

# Punto 3 esperanza del tiempo de parada
function expected_time(; βmin= 0.9, βmax = 0.99, N = 25)
    B = range(βmin, βmax, N)
    T = similar(B)
    for (i, x) in enumerate(B)
        mc = McCall(β = x, Nw = 1000)
        t = mean(tiempo_parada(mc))
        T[i] = t
    end
    return B, T
end

B, T = expected_time()

p4 = plot(B, T, label = L"E(T(β))")
savefig(p4, "./output/E(t(beta)).png")

# Punto 4: robustness
function E_v(mc::McCall; robust = false)
	if robust
        θ = mc.θ
        Tv = 0.0
        for jwp in eachindex(mc.wgrid)
            Tv += mc.pw[jwp] * exp(-θ * mc.v[jwp])
        end
        operador = (-1/θ)*log(Tv)
        return operador
    else
        Ev = 0.0
        for jwp in eachindex(mc.wgrid)
            Ev += mc.pw[jwp] * mc.v[jwp]
        end
        return Ev
	end
end

function vf_iter!(new_v, mc::McCall)
    flag = 0
    rechazar = u(mc.b, mc) + mc.β * E_v(mc, robust = true)
	for (jw, wv) in enumerate(mc.wgrid)
		aceptar = R(wv, mc)

		new_v[jw] = update_v(aceptar, rechazar)

		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv
			flag = 1
		end
	end
end

function pesimismo(; N=25, θmin = 1, θmax = 2)
    S = range(θmin, θmax, N)
    T = similar(S)
    V = similar(S)

    for (i, x) in enumerate(S)
        mc = McCall(θ=x, Nw = 10000)
        vfi!(mc)
        V[i] = mc.w_star
        t = mean(tiempo_parada(mc))
        T[i] = t
    end
    return V, T, S
end

V, T, S = pesimismo()

p5 = plot(S, V, label = L"w^*(θ)")

savefig(p5, "./output/w_star(theta).png")

p6 = plot(S, T, label = "E(T(\θ))")

savefig(p6, "./output/E(t(theta)).png")