#!/usr/bin/env julia

using Test
using FunOHDSI.Circe: unpack!
using JSON
using PrettyPrinting
using Pkg.Artifacts

function test_unpack(file)
    println('-' ^ 80)
    println(file)
    data = JSON.parsefile(file)
    expr = unpack!(data)
    pprintln(expr)
    pprintln(data)
    isempty(data)
end

for dir in readdir(joinpath(artifact"PhenotypeLibrary", "PhenotypeLibrary-0.0.1/inst"), join = true)
    isdir(dir) || continue
    for file in readdir(dir, join = true)
        endswith(file, ".json") || continue
        @test test_unpack(file)
    end
end
