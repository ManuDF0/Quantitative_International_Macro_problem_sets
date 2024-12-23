print("McCall, J. J. 'Economics of Information and Job Search' The Quarterly Journal of Economics, 1970, vol. 84, issue 1, 113-126\n")
print("Loading codes… ")

using Distributions, LinearAlgebra, StatsBase, PlotlyJS

# Defino la estructura McCall - Acuerdense que era como el nombre de la persona
# Qué implica el mutable adelante ? Por qué les parece que lo hacemos ? 
mutable struct McCall
	β::Float64
	γ::Float64

	b::Float64

	wgrid::Vector{Float64}
	pw::Vector{Float64}

	w_star::Float64 #Acá vamos a guardar las incognitas
	v::Vector{Float64} #Acá vamos a guardar las incognitas
end


# Los argumentos despues del ; son los que están NOMBRADOS. Cuando llamo la función, no lo lee por el orden sino por el nombre. 
# Los que estén a la izquierda del ; los lee por el orden. 

# Además, los valores despues del ; le asigno valores por default. 

#function h(;x=2 y=3)
#	2x + y
#end

function McCall(;
	β = 0.96,
	γ = 0,
	b = 1, 
	μw = 1, #Media de 2
	σw = 0.05, #Varianza de w
	Nσ = 0, # Le agrega varianza a la cantidad de puntos que le metemos
	wmin = 0.5, #Valos minimo de w
	wmax = 2,  #Valor maximo de w
	# Vamos a armar una grilla de muchos valores de w, entonces le ponemos los límites
	Nw = 500) #Puntos en el vector de posibles w. 
	# Cuantos puntos metemos en el intervalo de w

	if Nσ > 0  #Si le pongo Nσ distinto de cero, usa estos min y max
		wmin = μw - Nσ * σw
		wmax = μw + Nσ * σw
	end

    ## Mostrar valores del wgrid en base a distintos Nσ
	#x = McCall()
	#x.wgrid
	#x_sigma = McCall(Nσ=2)
	#x_sigma.wgrid

	wgrid = range(wmin, wmax, length=Nw) #Vector entre min y max, de longitud Nw

	w_star = first(wgrid) # El primer valor del grid es el star, ya lo vamos a usar

	d = Normal(μw, σw)

	pw = [pdf(d, wv) for wv in wgrid] #Para cada valor en la grilla le calcula la PDF de ese punto. 
    #Noten que la pw está entre corchetes, ya viene como un Vector
    # -> Un vector del mismo tamaño de wgrid con las probabilidades de cada punto. 

	pw = pw / sum(pw) # Va a ser la probabilidad de sacar cada uno de los w

	v = zeros(Nw)

	return McCall(β, γ, b, wgrid, pw, w_star, v) # me devuelve la estructura McCall que tenía antes (llama a la de arriba).
end


#Funcion de utilidad
function u(c, mc::McCall)
	γ = mc.γ
    #Si el γ es = 1, hace el log. Si da una distinta, hace la CES. Nos salvamos de la indeterminación.
	if γ == 1
		return log(c)
	else
		return c^(1-γ) / (1-γ)
	end
end

function R(w, mc::McCall)
	## Valor de aceptar una oferta w: R(w) = u(w) + β R(w)
	β = mc.β
	return u(w, mc) / (1-β)  #EL VALOR DE RECHAZAR
end

#La integral de la Value Function. 
function E_v(mc::McCall, θ = 0)
	## Valor esperado de la función de valor integrando sobre la oferta de mañana
	Ev = 0.0
    #Arranca en cero, y hace como una sumatoria (ya que por tener un grid es discreto como resolvemos). 
	for jwp in eachindex(mc.wgrid)
		if θ == 0
			Ev += mc.pw[jwp] * mc.v[jwp]
		else
			Ev += mc.pw[jwp] * exp(-θ * mc.v[jwp])
		end
	end
	if θ > 0
		Ev = -1/θ * log(Ev)
	end
	return Ev
end

function update_v(ac, re, EV)
	## Actualizar la función de valor con max(aceptar, rechazar) si EV es falso o usando la forma cerrada con el extreme value si EV es verdadero
	if EV
		χ = 2
		### Con Extreme Value type 1
		# Probabilidad de aceptar
		# prob = exp(ac/χ)/(exp(ac/χ)+exp(re/χ))
		# V = χ * log( exp(ac/χ) + exp(re/χ) )
		# return prob * ac + (1-prob) * re

		### Con Normal
		d = Normal(0,χ)
		prob = cdf(d, ac-re)
		cond_χ = truncated(d, re-ac, Inf) |> mean
		V = (1-prob) * re + prob * ac + cond_χ * prob
		return V
	else
		return max(ac, re)
	end
end


function vf_iter!(new_v, mc::McCall, θ = 0, flag = 0; EV=true)
	## Una iteración de la ecuación de Bellman

	# El valor de rechazar la oferta es independiente del estado de hoy
    # Es la funcion de utilidad (u), + el VA del esperado
	rechazar = u(mc.b, mc) + mc.β * E_v(mc, θ) 


	for (jw, wv) in enumerate(mc.wgrid)  #Lo que vimos, te da el incide y el valor
		# El valor de aceptar la oferta sí depende de la oferta de hoy
        #SIEMPRE el jw es el indice, y wv los valores de w.

        #El valor de aceptar, que es en base a la función R (arriba)
		aceptar = R(wv, mc)

		# Para una oferta w, v(w) es lo mejor entre aceptar y rechazar - toma el maximo y lo pone dentro de la new_v para cada elemento
		new_v[jw] = update_v(aceptar, rechazar, EV)

		# El salario de reserva es la primera vez que aceptar es mejor que rechazar
        #Se basa en el vector de los salarios está ascendente. El flag arranca con cero, y cuando llega al primer salario para el que acepto 
        # (el de reserva) lo marco con una flag. Ese es el salario de reserva. 

		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv # Lo guardo como el star (de reserva)
			flag = 1
		end
	end
end

# usa McCall (la estructura), y tiene parametros de iteraciones maximas, tolerancia. verbose si quiero o no hacer print de resultados. 
#Esto se repite para mucho de los modelos. 
function vfi!(mc::McCall, θ = 0; maxiter = 2000, tol = 1e-8, verbose=true)  
	dist, iter = 1+tol, 0

	new_v = similar(mc.v) #Crea un elemento igual a lo que hay adentro, pero con valores ceros. 

    #El while mientras sea verdadero sigue. Si distancia e iteraciones no llegan al tope, sigue. 
	while dist > tol && iter < maxiter
		iter += 1  #Le voy sumando 1 al numero de iteraciones en cada corrida.
		vf_iter!(new_v, mc, θ)  #Llamo a la función vf_iter!, que va llenando la nueva v (valor)
		dist = norm(mc.v - new_v) # La distancia en la diferencia entre la nueva y la vieja v
		mc.v .= new_v #Vuelvo la nueva v adentro del modelo. El ".=" me dice que lo que le estoy asignando a mc.v NO ESTA PEGADO a new_v

        # a = [1, 2, 3]
        # b = a
        #b[2] = 8
        #b
        #a
	end

    # Hace print de resultado, me dice que paro por max iteraciones o si llegó a resultado
	if verbose
		if iter == maxiter
			print("Stopped after ")
		else
			print("Finished in ")
		end
		print("$iter iterations.\nDist = $dist\n")
	end
end

# Con el modelo resuelto, agarra un w al azar de la distribución y me dice si agarró o no. Osea, si es mayor o no al de reserva. 
function simul(mc::McCall, flag = 0; maxiter = 2000, verbose::Bool=true)
	t = 0
	PESOS = Weights(mc.pw) #Esto despues cambia por cadenas de Markov.
	while flag == 0 && t < maxiter
		t += 1
		wt = sample(mc.wgrid, PESOS)
		verbose && print("Salario en el período $t: $wt. ")
		verbose && sleep(0.1)
		wt >= mc.w_star ? flag = 1 : verbose && println("Sigo buscando")
	end
	
	(verbose && flag == 1) && println("Oferta aceptada en $t períodos")
	
	return t
end




function make_plots(mc::McCall)

    aceptar_todo = [R(wv, mc) for wv in mc.wgrid]
    at = scatter(x=mc.wgrid, y=aceptar_todo, line_color="#f97760", name="u(w) / (1-β)")

    rechazar_todo = [u(mc.b, mc) + mc.β * E_v(mc) for wv in mc.wgrid]
    rt = scatter(x=mc.wgrid, y=rechazar_todo, line_color="#0098e9", name="u(b) + β ∫v(z) dF(z)")

    opt = scatter(x=mc.wgrid, y=mc.v, line_color="#5aa800", line_width=3, name="v(w)")

    traces = [at, rt, opt]

    shapes = [vline(mc.w_star, line_dash="dot", line_color="#818181")]

    annotations = [attr(x=mc.w_star, y=0, yanchor="top", yref="paper", showarrow=false, text="w*")]

    layout = Layout(shapes=shapes,
        annotations=annotations,
        title="Value function in McCall's model",
        width=1920 * 0.5, height=1080 * 0.5,
        legend=attr(orientation="h", x=0.05),
        xaxis=attr(zeroline=false, gridcolor="#434343"),
        yaxis=attr(zeroline=false, gridcolor="#434343"),
        paper_bgcolor="#272929", plot_bgcolor="#272929",
        font_color="#F8F1E9", font_size=16,
        font_family="Lato",
        hovermode="x",
    )

    plot(traces, layout)
end

# Puedo cambiarle el γ y graficar distinto
# mc.γ
# mc.γ = 1
# vfi!(mc)
#make_plots()


function dist_T(mc::McCall, K = 100)
	Tvec = Vector{Int64}(undef, K)
	for jt in eachindex(Tvec)
		Tvec[jt] = simul(mc, verbose=false)
	end
	Tvec
end

print("✓\nConstructor mc = McCall(; β = 0.96, γ = 0, b = 1, μw = 1, σw = 0.05, wmin = 0.5, wmax = 2, Nw = 50\n")
print("Main loop vfi!(mc)\n")