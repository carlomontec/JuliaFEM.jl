# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

""" Heat equations.

Field equation is:

    ρc∂u/∂t = ∇⋅(k∇u) + f

Weak form is: find u∈U such that ∀v in V

    ∫k∇u∇v dx = ∫fv dx + ∫gv ds,

where

    k = temperature thermal conductivity    defined on volume elements
    f = temperature load                    defined on volume elements
    g = temperature flux                    defined on boundary elements

Parameters
----------
temperature thermal conductivity
temperature load
temperature flux
thermal conductivity
heat source
heat flux
heat transfer coefficient
external temperature


Formulations
------------
1D, 2D, 3D

References
----------
https://en.wikipedia.org/wiki/Heat_equation
https://en.wikipedia.org/wiki/Heat_capacity
https://en.wikipedia.org/wiki/Heat_flux
https://en.wikipedia.org/wiki/Thermal_conduction
https://en.wikipedia.org/wiki/Thermal_conductivity
https://en.wikipedia.org/wiki/Thermal_diffusivity
https://en.wikipedia.org/wiki/Volumetric_heat_capacity
"""
type Heat <: FieldProblem
    formulation :: AbstractString
    store_fields :: Vector{Symbol}
end

function Heat()
    return Heat("3D", [])
end

function get_unknown_field_name(problem::Problem{Heat})
    return "temperature"
end

function assemble!(assembly::Assembly, problem::Problem{Heat}, element::Element, time::Float64)
    formulation = Val{Symbol(problem.properties.formulation)}
    assemble!(assembly, problem, element, time, formulation)
end

# 3d heat problems

function assemble!{E}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("3D")}})
    info("Unknown element type $E for 3d heat problem!")
end

const Heat3DVolumeElements = Union{Tet4, Tet10, Pyr5, Hex8, Hex20, Hex27}
const Heat3DSurfaceElements = Union{Tri3,Tri6,Quad4,Quad8,Quad9}

function assemble!{E<:Heat3DVolumeElements}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("3D")}})
    gdofs = get_gdofs(problem, element)
    field_name = get_unknown_field_name(problem)
    nnodes = length(element)
    K = zeros(nnodes, nnodes)
    fq = zeros(nnodes)
    for ip in get_integration_points(element)
        detJ = element(ip, time, Val{:detJ})
        w = ip.weight*detJ
        N = element(ip, time)
        if haskey(element, "$field_name thermal conductivity")
            dN = element(ip, time, Val{:Grad})
            k = element("$field_name thermal conductivity", ip, time)
            K += w*k*dN'*dN
        end
        if haskey(element, "thermal conductivity")
            dN = element(ip, time, Val{:Grad})
            k = element("thermal conductivity", ip, time)
            K += w*k*dN'*dN
        end
        if haskey(element, "$field_name load")
            f = element("$field_name load", ip, time)
            fq += w*N'*f
        end
        if haskey(element, "heat source")
            f = element("heat source", ip, time)
            fq += w*N'*f
        end
    end
    T = [interpolate(element[field_name], time)...]
    fq -= K*T
    add!(assembly.K, gdofs, gdofs, K)
    add!(assembly.f, gdofs, fq)
end

function assemble!{E<:Heat3DSurfaceElements}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("3D")}})
    gdofs = get_gdofs(problem, element)
    field_name = get_unknown_field_name(problem)
    nnodes = length(element)
    K = zeros(nnodes, nnodes)
    fq = zeros(nnodes)
    for ip in get_integration_points(element, 2)
        detJ = element(ip, time, Val{:detJ})
        w = ip.weight*detJ
        N = element(ip, time)
        if haskey(element, "$field_name flux")
            q = element("$field_name flux", ip, time)
            fq += w*N'*q
        end
        if haskey(element, "heat flux")
            q = element("heat flux", ip, time)
            fq += w*N'*q
        end
        if haskey(element, "$field_name heat transfer coefficient") && haskey(element, "$field_name external temperature")
            h = element("$field_name heat transfer coefficient", ip, time)
            Tu = element("$field_name external temperature", ip, time)
            K += w*h*N'*N
            fq += w*N'*h*Tu
        end
        if haskey(element, "heat transfer coefficient") && haskey(element, "external temperature")
            h = element("heat transfer coefficient", ip, time)
            Tu = element("external temperature", ip, time)
            K += w*h*N'*N
            fq += w*N'*h*Tu
        end
    end
    T = collect(element(field_name, time))
    fq -= K*T
    add!(assembly.K, gdofs, gdofs, K)
    add!(assembly.f, gdofs, fq)
end

# 2d heat problems

function assemble!{E}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("2D")}})
    info("Unknown element type $E for 2d heat problem!")
end

const Heat2DVolumeElements = Union{Tri3,Tri6,Quad4}
const Heat2DSurfaceElements = Union{Seg2,Seg3}

function assemble!{E<:Heat2DVolumeElements}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("2D")}})
    gdofs = get_gdofs(problem, element)
    field_name = get_unknown_field_name(problem)
    nnodes = length(element)
    K = zeros(nnodes, nnodes)
    fq = zeros(nnodes)
    for ip in get_integration_points(element)
        detJ = element(ip, time, Val{:detJ})
        w = ip.weight*detJ
        N = element(ip, time)
        if haskey(element, "$field_name thermal conductivity")
            dN = element(ip, time, Val{:Grad})
            k = element("$field_name thermal conductivity", ip, time)
            K += w*k*dN'*dN
        end
        if haskey(element, "thermal conductivity")
            dN = element(ip, time, Val{:Grad})
            k = element("thermal conductivity", ip, time)
            K += w*k*dN'*dN
        end
        if haskey(element, "$field_name load")
            f = element("$field_name load", ip, time)
            fq += w*N'*f
        end
        if haskey(element, "heat source")
            f = element("heat source", ip, time)
            fq += w*N'*f
        end
    end
    T = collect(element(field_name, time))
    fq -= K*T
    add!(assembly.K, gdofs, gdofs, K)
    add!(assembly.f, gdofs, fq)
end

function assemble!{E<:Heat2DSurfaceElements}(assembly::Assembly, problem::Problem{Heat}, element::Element{E}, time, ::Type{Val{Symbol("2D")}})
    gdofs = get_gdofs(problem, element)
    field_name = get_unknown_field_name(problem)
    nnodes = length(element)
    K = zeros(nnodes, nnodes)
    fq = zeros(nnodes)
    for ip in get_integration_points(element)
        detJ = element(ip, time, Val{:detJ})
        w = ip.weight*detJ
        N = element(ip, time)
        if haskey(element, "$field_name flux")
            g = element("$field_name flux", ip, time)
            fq += w*N'*g
        end
        if haskey(element, "heat flux")
            g = element("heat flux", ip, time)
            fq += w*N'*g
        end
        if haskey(element, "$field_name heat transfer coefficient") && haskey(element, "$field_name external temperature")
            h = element("$field_name heat transfer coefficient", ip, time)
            Tu = element("$field_name external temperature", ip, time)
            K += w*h*N'*N
            fq += w*N'*h*Tu
        end
        if haskey(element, "heat transfer coefficient") && haskey(element, "external temperature")
            h = element("heat transfer coefficient", ip, time)
            Tu = element("external temperature", ip, time)
            K += w*h*N'*N
            fq += w*N'*h*Tu
        end
    end
    T = collect(element(field_name, time))
    fq -= K*T
    add!(assembly.K, gdofs, gdofs, K)
    add!(assembly.f, gdofs, fq)
end
