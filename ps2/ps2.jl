include("cakeeating.jl")

using Plots, LaTeXStrings

# Punto 1
ce = CakeEating(Nk = 2300)
vfi!(ce)

p1 = plot(ce.kgrid, ce.gc, label = L"c_t(k_t)")
savefig(p1, "./output/c(k).png")

fraccion = ce.gc./ce.kgrid
p2 = plot(ce.kgrid, fraccion, label = L"\frac{c_t(k_t)}{k_t}")
savefig(p2, "./output/c(k)_k.png")

fraccion_capital = ce.gk./ce.kgrid
p3 = plot(ce.kgrid, fraccion_capital, label = L"\frac{k_{t+1}(k_t)}{k_t} ")
savefig(p3, "./output/k(k)_k.png")

# Interpolado
include("itpcake.jl")
ce_itp = CakeEating()
vfi_itp!(ce_itp)

p4 = plot(ce_itp.kgrid, ce_itp.gc, label = L"c_t(k_t)")
savefig(p4, "./output/c(k)_itp.png")

fraccion_itp = ce_itp.gc./ce_itp.kgrid
p5 = plot(ce_itp.kgrid, fraccion_itp, label = L"\frac{c_t(k_t)}{k_t}")
savefig(p5, "./output/c(k)_k_itp.png")

fraccion_capital = ce_itp.gk./ce_itp.kgrid
p6 = plot(ce_itp.kgrid, fraccion_capital, label = L"\frac{k_{t+1}(k_t)}{k_t}")
savefig(p6, "./output/k_t+1(k)_k_itp.png")

function  simulator(ce::CakeEating; T = 100, k0 = 0.8)
    vfi_itp!(ce)
    if k0 <= maximum(ce.kgrid)
        k0 = k0
    else
        k0 = rand(ce.kgrid)
    end

    knts = (ce.kgrid,)
    C = zeros(T)
    K = zeros(T)

    itp_c = interpolate(knts, ce.gc, Gridded(Linear()))
    itp_k = interpolate(knts, ce.gk, Gridded(Linear()))

    for t in range(1, T)
        k = itp_k(k0)
        c = itp_c(k0)

        C[t] = c
        K[t] = k

        k0 = k
    end
    return C, K
end

ce_itp = CakeEating()
C, K = simulator(ce_itp)

p6 = plot(1:100, C, label = L"c(t)")
savefig(p6, "./output/c(t).png")

consumo_acumulado = cumsum(C)
p7 = plot(1:100, consumo_acumulado, label = L"\sum^T_{t=0} c(T)")
savefig(p7, "./output/consumo_acumulado.png")

p8 = plot(1:100, K, label = L"k(t)")
savefig(p8, "./output/k(t).png")
