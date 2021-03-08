@inline function C_e(CellData::Cell,FCall::FCalls,s,z)
""" 
Electrolyte Concentration Transfer Function
# Add License
# Add Ins and Outs
    # Locations to be computed
    # Sampling Frequency
"""

T = CellData.Const.T      # Temperature
t_plus = CellData.Const.t_plus  # Transference Number
ζ = (1-t_plus)/F    #Simplifying Variable
Ds_Neg = CellData.Neg.Ds       # Solid diffusivity [m^2/s]
Ds_Pos = CellData.Pos.Ds       # Solid diffusivity [m^2/s]
CC_A = CellData.Geo.CC_A   # Current-collector area [m^2]
κ_eff_Neg = FCall.Kap.κ*ϵ1^CellData.Neg.κ_brug
κ_eff_Pos = FCall.Kap.κ*ϵ3^CellData.Pos.κ_brug
σ_eff_Neg = CellData.Neg.σ*CellData.Neg.ϵ_s^CellData.Neg.σ_brug #Effective Conductivity Neg
σ_eff_Pos = CellData.Pos.σ*CellData.Pos.ϵ_s^CellData.Pos.σ_brug #Effective Conductivity Pos

#Defining SOC
θ_neg = CellData.Const.Init_SOC * (CellData.Neg.θ_100-CellData.Neg.θ_0) + CellData.Neg.θ_0 
θ_pos = CellData.Const.Init_SOC * (CellData.Pos.θ_100-CellData.Pos.θ_0) + CellData.Pos.θ_0 

#Beta's
s = s'
βn = @. CellData.Neg.Rs*sqrt(s/Ds_Neg)
βp = @. CellData.Pos.Rs*sqrt(s/Ds_Pos)

#Prepare for j0
ce0 = CellData.Const.ce0
cs_max_neg = CellData.Neg.cs_max
cs0_neg = cs_max_neg * θ_neg
cs_max_pos = CellData.Pos.cs_max
cs0_pos = cs_max_pos * θ_pos

#Current Flux Density
κ_pos = CellData.Pos.k_norm/CellData.Pos.cs_max/ce0^(1-CellData.Pos.α)
κ_neg = CellData.Neg.k_norm/CellData.Neg.cs_max/ce0^(1-CellData.Neg.α)
j0_neg = κ_neg*(ce0*(cs_max_neg-cs0_neg))^(1-CellData.Neg.α)*cs0_neg^CellData.Neg.α
j0_pos = κ_pos*(ce0*cs_max_pos*cs0_pos)^(1-CellData.Pos.α)*cs0_pos^CellData.Pos.α

#Resistances
Rtot_neg = R*CellData.Const.T/(j0_neg*F^2) + CellData.Neg.RFilm
Rtot_pos = R*CellData.Const.T/(j0_pos*F^2) + CellData.Pos.RFilm

#OCP derivative
∂Uocp_pos = ∂Uocp("Pos",θ_pos)
∂Uocp_neg = ∂Uocp("Neg",θ_neg)

#Condensing Variable
ν_n =  @. Lneg*sqrt((as_neg/σ_eff_Neg+as_neg/κ_eff_Neg)/(Rtot_neg+∂Uocp_neg*(CellData.Neg.Rs/(F*Ds_Neg))*(tanh(βn)/(tanh(βn)-βn))))
ν_p =  @. Lpos*sqrt((as_pos/σ_eff_Pos+as_pos/κ_eff_Pos)/(Rtot_pos+∂Uocp_pos*(CellData.Pos.Rs/(F*Ds_Pos))*(tanh(βp)/(tanh(βp)-βp))))

λ = roots(CellData.RA.M+1)
λ = (λ[1:size(λ,1) .!= 1,: ]) #Delete first element relating to location zero

#Create all k's
in1 = sqrt.(λ.*ϵ1./D1)
in2 = sqrt.(λ*ϵ2./D2)
in3 = sqrt.(λ*ϵ3./D3)

Bound_Neg_1 = Lneg * in1
Bound_Sep_0 = Lneg * in2
Bound_Sep_1 = (Lneg+Lsep) * in2
Bound_Pos_0 = (Lneg+Lsep) * in3
Bound_Pos_1 = Ltot * in3
Bound_Pos_2 = Lpos * in3

#Scaled coefficients
k3_s = cos.(Bound_Neg_1).*cos.(Bound_Sep_0)+D1*in1.*sin.(Bound_Neg_1).*sin.(Bound_Sep_0)./(D2*in2)
k4_s = cos.(Bound_Neg_1).*sin.(Bound_Sep_0) - D1*in1.*cos.(Bound_Sep_0).*sin.(Bound_Neg_1)./(D2*in2);
k5_s = k3_s.*(cos.(Bound_Sep_1).*cos.(Bound_Pos_1)+D2*in2.*sin.(Bound_Sep_1).*sin.(Bound_Pos_1)./(D3*in3))+k4_s.*(sin.(Bound_Sep_1).*cos.(Bound_Pos_1)-D2*in2.*cos.(Bound_Sep_1).*sin.(Bound_Pos_1)./(D3*in3));
k6_s = k3_s.*(cos.(Bound_Sep_1).*sin.(Bound_Pos_1)-D2*in2.*sin.(Bound_Sep_1).*cos.(Bound_Pos_1)./(D3*in3))+k4_s.*(sin.(Bound_Sep_1).*sin.(Bound_Pos_1)+D2*in2.*cos.(Bound_Sep_1).*cos.(Bound_Pos_1)./(D3*in3));


#Solving for k1:
Int_ψ1 = ϵ1*(2*Bound_Neg_1+sin.(2*Bound_Neg_1)./(4*in1))
Int_ψ2 = ϵ2./(4*in2) .* (2 .* (k3_s.^2 .+ k4_s.^2) .* Lsep .* in2 + 2*k3_s .* k4_s .* cos.(2 .* Bound_Sep_0) .- 2 .* k3_s .* k4_s .* cos.(2 .* Bound_Sep_1) .- (k3_s .- k4_s) .* (k3_s .+ k4_s) .* (sin.(2 .* Bound_Sep_0) .- sin.(2 .* Bound_Sep_1)))
Int_ψ3 = ϵ3./(4*in3) .* (2 .* (k5_s.^2+k6_s.^2) .* Lpos .* in3 + 2*k5_s .* k6_s .* cos.(2 .* Bound_Pos_0) .- 2 .* k5_s .* k6_s .* cos.(2 .* Bound_Pos_1) .- (k5_s .- k6_s) .* (k5_s .+ k6_s) .* (sin.(2 .* Bound_Pos_0) .- sin.(2 .* Bound_Pos_1)))


k1 = @. 1/(sqrt(Int_ψ1+Int_ψ2+Int_ψ3))
k3 = @. k1*k3_s
k4 = @. k1*k4_s
k5 = @. k1*k5_s
k6 = @. k1*k6_s


j_Neg = @. ((κ_eff_Neg+σ_eff_Neg)*cosh(ν_n)*ν_n)*(k1*ζ*Bound_Neg_1*sin(Bound_Neg_1))/(ν_n^2*sinh(ν_n)+CC_A*(κ_eff_Neg+σ_eff_Neg)*((Bound_Neg_1^2)))

Hlp1 = σ_eff_Pos+κ_eff_Pos
Hlp2 = @. (Hlp1*cosh(ν_p)*ν_p)
Hlp3 = @. (Bound_Pos_2^2)+ν_p^2*sinh(ν_p)

j_Pos1 = @. (k6*ζ*Bound_Pos_2*cos(Bound_Pos_1)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos2 = @. (k5*ζ*Bound_Pos_2*sin(Bound_Pos_2)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos3 = @. (k6*ζ*Bound_Pos_2*cos(Bound_Pos_0)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos4 = @. (k5*ζ*Bound_Pos_2*sin(Bound_Pos_1)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos5 = @. (k5*ζ*σ_eff_Pos*cos(Bound_Pos_0)*κ_eff_Pos*cos(Bound_Pos_1)*ν_p^2)/(CC_A*Hlp1*(Bound_Pos_2^2 + ν_p^2))
j_Pos6 = @. (k6*ζ*σ_eff_Pos*sin(Bound_Pos_0)*κ_eff_Pos*sin(Bound_Pos_1)*ν_p^2)/(CC_A*Hlp1*(Bound_Pos_2^2 + ν_p^2))

j_Pos = j_Pos1 - j_Pos2 + j_Pos3 - j_Pos4 - j_Pos5 - j_Pos6

C_e =  @. ((j_Neg + j_Pos)/(s+λ))

i=1
ψ = fill(0.0,1,length(z))
for x in z #Eigen Weighting
    if x < Lneg
       ψ[i] = k1[i]*cos(in1[i]*x) #negative electrode
    elseif x < Lnegsep
        ψ[i] = @. k3[i]*cos(in2[i]*x)+k4[i]*sin(in2[i]*x) # separator
    else
        ψ[i] = @. k5[i]*cos(in3[i]*x)+k6[i]*sin(in3[i]*x) # postive electrode
    end
i = i+1
end
ψ_dims = ψ.*diagm(0=>fill(1., size(ψ,2)))
C_e = ψ_dims*C_e

D_term = zeros(length(z))
res0 = zeros(length(z))
return C_e, D_term, res0
end

function roots(roots_n)
    root = Number[0]
    i = 0.00001
    ∇ = 0.00001
    if(roots_n > 1)
        while length(root) <= roots_n-1
            if flambda(i-∇)*flambda(i)<0
            push!(root, find_zero(flambda,(i-∇,i)))
            end
        i = i+∇
        end
    end
    return root
end

function flambda(λ)
    k1 = 1
    sle1 = sqrt(λ*ϵ1/D1)
    sle2 = sqrt(λ*ϵ2/D2)
    sle3 = sqrt(λ*ϵ3/D3)
    k3 = k1*(cos(sle1*Lneg).*cos(sle2*Lneg) + D1*sle1.*sin(sle1*Lneg).*sin(sle2*Lneg)./(D2*sle2))
    k4 = k1*(cos(sle1*Lneg).*sin(sle2*Lneg) - D1*sle1.*cos(sle2*Lneg).*sin(sle1*Lneg)./(D2*sle2))
    k5 = k3*(cos(sle2*Lnegsep).*cos(sle3*Lnegsep) + D2*sle2.*sin(sle2*Lnegsep).*sin(sle3*Lnegsep)./(D3*sle3))+k4*(sin(sle2*Lnegsep).*cos(sle3*Lnegsep) - D2*sle2.*cos(sle2*Lnegsep).*sin(sle3*Lnegsep)./(D3*sle3))
    k6 = k3*(cos(sle2*Lnegsep).*sin(sle3*Lnegsep) - D2*sle2.*sin(sle2*Lnegsep).*cos(sle3*Lnegsep)./(D3*sle3))+k4*(sin(sle2*Lnegsep).*sin(sle3*Lnegsep) + D2*sle2.*cos(sle2*Lnegsep).*cos(sle3*Lnegsep)./(D3*sle3))
    Psiprime = -k5.*sle3.*sin(sle3*Ltot) + k6.*sle3.*cos(sle3*Ltot)
  end