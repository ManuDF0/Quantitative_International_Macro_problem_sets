function make_itp(dd::NoDefault, y::Array{Float64,2})
	@assert size(y) == (length(dd.bgrid), length(dd.ygrid))

	knts = (dd.bgrid, dd.ygrid)
	interpolate(knts, y, Gridded(Linear()))
end

function simul(dd::NoDefault; T = 250, b0 = 0., y0 = 1.)

    bvec = zeros(T)
    yvec = zeros(T)
    cvec = zeros(T)

    itp_gb = make_itp(dd, dd.gb)
    itp_gc = make_itp(dd, dd.gc)

    for jt in 1:T

        # Guardo el estado
        bvec[jt] = b0
        yvec[jt] = y0


        # Me fijo cómo actúo en t
        bp, c = action_t(b0, y0, itp_gb, itp_gc)

        cvec[jt] = c

        # Realizo los shocks para ir a t+1
        yp = transition(y0, dd)

        # Lo que en t es mañana, en t+1 es hoy
        b0 = bp
        y0 = yp
    end

    return bvec, yvec, cvec
end

function action_t(b, y, itp_gb, itp_gc)
    c = itp_gc(b,y,1)
    bp = itp_gb(b,y)

    return bp, c
end

function transition(y, dd)
    ymin, ymax = extrema(dd.ygrid)
    ρ, σ = dd.pars[:ρy], dd.pars[:σy]

    ly = log(y)
    ϵ = rand(Normal(0,1))
    lyp = ρ * ly + σ * ϵ
    yp = exp(lyp)

    yp = max(ymin, min(ymax, yp))

    return yp
end