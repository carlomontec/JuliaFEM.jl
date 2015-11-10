# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

module TestAutoDiffWeakForm

using JuliaFEM.Test
using JuliaFEM
using JuliaFEM: Quad4, Equation, IntegrationPoint,
                solve!, get_field, get_element, get_basis,
                grad

""" Plane stress formulation for 4-node bilinear element. """
type CPS4 <: Equation
    element :: Quad4
    integration_points :: Array{IntegrationPoint, 1}
end

function CPS4(element::Quad4)
    integration_points = [
        IntegrationPoint(1.0/sqrt(3.0)*[-1, -1], 1.0),
        IntegrationPoint(1.0/sqrt(3.0)*[ 1, -1], 1.0),
        IntegrationPoint(1.0/sqrt(3.0)*[ 1,  1], 1.0),
        IntegrationPoint(1.0/sqrt(3.0)*[-1,  1], 1.0)]
    if !haskey(element, "displacement")
        # initial field must be defined if using autodiff
        element["displacement"] = zeros(2, 4)
    end
    CPS4(element, integration_points)
end

JuliaFEM.size(eq::CPS4) = (2, 4)

function JuliaFEM.get_residual_vector(equation::CPS4, ip, time; variation=nothing)
    element = get_element(equation)
    basis = get_basis(element)
    dbasis = grad(basis)

    # material parameters
    E = basis("youngs modulus", ip, time)
    nu = basis("poissons ratio", ip, time)
    mu = E/(2*(1+nu))
    la = E*nu/((1+nu)*(1-2*nu))
    la = 2*la*mu/(la + 2*mu)  # <- correction for 2d

    # elasticity formulation
    u = basis("displacement", ip, time, variation)
    gradu = dbasis("displacement", ip, time, variation)
    F = I + gradu
    b = basis("displacement volume load", ip, time)
    E = 1/2*(F'*F - I)
    S = la*trace(E)*I + 2*mu*E
    P = F*S

    # residual vector
    r_int = P*dbasis(ip,time)
    r_ext = b*basis(ip,time)
    r = r_int - r_ext
    return vec(r)
end

JuliaFEM.has_residual_vector(equation::CPS4) = true

function test_residual_form()
    # create model -- start
    element = Quad4([1, 2, 3, 4])
    element["geometry"] = Vector[[0.0,0.0], [10.0,0.0], [10.0,1.0], [0.0,1.0]]
    element["youngs modulus"] = 500.0
    element["poissons ratio"] = 0.3
    element["displacement volume load"] = Vector[[0.0,-10.0], [0.0,-10.0], [0.0,-10.0], [0.0,-10.0]]
    equation = CPS4(element)
    # create model -- end

    free_dofs = [3, 4, 5, 6]
    solve!(equation, "displacement", free_dofs)  # launch a newton solver for single element
    disp = get_basis(element)("displacement", [1.0, 1.0])[2]
    println("displacement at tip: $disp")
    # verified using Code Aster.
    @test isapprox(disp, -8.77303119819776E+00)
end

end