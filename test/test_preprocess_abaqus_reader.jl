# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

using JuliaFEM
using JuliaFEM.Preprocess
using JuliaFEM.Abaqus
using JuliaFEM.Testing
using JuliaFEM.Preprocess: element_has_nodes, element_has_type

@testset "read inp file" begin
    model = open(parse_abaqus, joinpath(Pkg.dir("JuliaFEM"),"geometry","3d_beam","palkki.inp"))
    @test length(model["nodes"]) == 298
    @test length(model["elements"]) == 120
    @test length(model["elsets"]["Body1"]) == 120
    @test length(model["nsets"]["SUPPORT"]) == 9
    @test length(model["nsets"]["LOAD"]) == 9
    @test length(model["nsets"]["TOP"]) == 83
end

@testset "test read element section" begin
    data = """*ELEMENT, TYPE=C3D10, ELSET=BEAM
    1,       243,       240,       191,       117,       245,       242,       244,
    1,         2,       196
    2,       204,       199,       175,       130,       207,       208,       209,
    3,         4,       176
    """
    data = split(data, "\n")
    model = Dict{AbstractString, Any}()
    model["nsets"] = Dict{AbstractString, Vector{Int}}()
    model["elsets"] = Dict{AbstractString, Vector{Int}}()
    model["elements"] = Dict{Integer, Any}()
    parse_section(model, data, :ELEMENT, 1, 5, Val{:ELEMENT})
    @test length(model["elements"]) == 2
    @test model["elements"][1]["connectivity"] == [243, 240, 191, 117, 245, 242, 244, 1, 2, 196]
    @test model["elements"][2]["connectivity"] == [204, 199, 175, 130, 207, 208, 209, 3, 4, 176]
    @test model["elsets"]["BEAM"] == [1, 2]
end

@testset "parse nodes from abaqus .inp file to Mesh" begin
    fn = joinpath(Pkg.dir("JuliaFEM"), "test", "testdata","cube_tet4.inp")
    mesh = abaqus_read_mesh(fn)
    info(mesh.surface_sets)
    @test length(mesh.nodes) == 10
    @test length(mesh.elements) == 17
    @test haskey(mesh.elements, 1)
    @test mesh.elements[1] == [8, 10, 1, 2]
    @test mesh.element_types[1] == :Tet4
    @test haskey(mesh.node_sets, :SYM12)
    @test haskey(mesh.element_sets, :CUBE)
    @test haskey(mesh.surface_sets, :LOAD)
    @test haskey(mesh.surface_sets, :ORDER)
    @test length(mesh.surface_sets[:LOAD]) == 2
    @test mesh.surface_sets[:LOAD][1] == (16, :S1)
    @test mesh.surface_types[:LOAD] == :ELEMENT
    @test length(Set(map(size, values(mesh.nodes)))) == 1
    elements = create_surface_elements(mesh,:LOAD)
    @test get_connectivity(elements[1]) == [8,10,9]
end

@testset "parse nodes from abaqus .inp file to Mesh (NX export)" begin
    fn = joinpath(Pkg.dir("JuliaFEM"), "test", "testdata","nx_export_problem.inp")
    mesh = abaqus_read_mesh(fn)
    @test length(mesh.nodes) == 3
end

@testset "parse abaqus .inp created using hypermesh" begin
    data = """
**
** ABAQUS Input Deck Generated by HyperMesh Version  : 14.0.120.28
** Generated using HyperMesh-Abaqus Template Version : 14.0.120
**
**   Template:  ABAQUS/STANDARD 3D
**
*NODE , Nset = nset_csys0
         1,  2.649428       ,  -21.93735      ,  217.2934
         2,  27.54531       ,  1.108443       ,  228.8077
"""
	fn = tempname() * ".inp"
    open(fn, "w") do fid write(fid, data) end
    mesh = abaqus_read_mesh(fn)
    @test length(mesh.nodes) == 2
end

@testset "Elemement types and nodes" begin
    @test element_has_nodes(Val{:C3D4}) == 4
    @test element_has_type(Val{:C3D4}) == :Tet4
    @test element_has_nodes(Val{:C3D8}) == 8
    @test element_has_type(Val{:C3D8}) == :Hex8
    @test element_has_nodes(Val{:C3D10}) == 10
    @test element_has_type(Val{:C3D10}) == :Tet10
    @test element_has_nodes(Val{:C3D20}) == 20
    @test element_has_nodes(Val{:C3D20E}) == 20
    @test element_has_nodes(Val{:S3}) == 3
    @test element_has_type(Val{:S3}) == :Tri3
    @test element_has_nodes(Val{:STRI65}) == 6
    @test element_has_type(Val{:STRI65}) == :Tri6
    @test element_has_nodes(Val{:CPS4}) == 4
    @test element_has_type(Val{:CPS4}) == :Quad4
end

@testset "GENERATE keyword" begin
    data = """
*NSET, NSET=testgen, GENERATE
7,13,2
"""
    fn = tempname() * ".inp"
    open(fn, "w") do fid write(fid, data) end
    mesh = abaqus_read_mesh(fn)
    @test mesh.node_sets[:testgen] == Set([7,9,13,11])
end
