# Punto 2
include("cakeeating.jl")
include("itpcake.jl")

using Plots

# Backwards Induction
function budget_constraint(kpv, kv, r)
	# La torta de hoy (más intereses) financia el consumo de hoy y la torta de mañana
	c = kv * (1+r) - kpv
	return c
end

function eval_value(kpv, kv, itp_v::AbstractInterpolation, ce::CakeEating)
	## Evalúa la función de valor en kv cuando se eligió kpv
	β, r = ce.pars[:β], ce.pars[:r]

	cv = budget_constraint(kpv, kv, r)

	cv > 0 || throw(error("Consumo negativo!!!!!"))
	
	# Utilidad de consumir cv
	ut = u(cv, ce)

	# Evalúa la interpolación de la función de valor en kv (nivel, no índice)
	vp = itp_v(kv)

	v = ut + β * vp

	return v
end

function simulator(ce::CakeEating; T = 100)
    vfi_itp!(ce)
    knts = (ce.kgrid,)
    itp_v = interpolate(knts, ce.v, Gridded(Linear()))
    r = ce.pars[:r]

    C = zeros(T)
    K = zeros(T + 1) 

    K[T + 1] = 1.0e-6 # Fijo el capital del último periodo en (prácticamente) 0
    k_next = K[T + 1]
    for t in 1:T
        if T - t == 0
            break
        end

        k_max = maximum(ce.kgrid)

        k_min = k_next/(1+r) # Ayer tenía por lo menos tanto como tengo hoy (descontado)
        k_min = max(k_min, minimum(ce.kgrid))

        obj_f(kv) = eval_value(k_next, kv, itp_v, ce) # Dado el capital de mañana, busco el capital de ayer que maximiza la función de valor
        res = Optim.maximize(obj_f, k_min, k_max)
        k_star = Optim.maximizer(res) # El valor de capital de ayer que maximiza la función de valor
        c_star = budget_constraint(k_next, k_star, r) # Dado el capital de hoy y de mañana puedo sacar el consumo

        C[T-t + 1] = c_star
        K[T-t] = k_star
        k_next = k_star
    end

    return C, K
end

ce_itp = CakeEating()
C, K = simulator(ce_itp)

p8 = plot(1:100, C)

p9 = plot(1:100, K)
