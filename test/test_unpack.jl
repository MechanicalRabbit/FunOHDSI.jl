#!/usr/bin/env julia

using Test
using FunOHDSI.Legacy: unpack!
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

invalid_circe_be_cohort_files = [
    "additionalCriteriaCheckValueIncorrect.json",
    "censoringEventCheckValueIncorrect.json",
    "conceptSetWithDuplicateItems.json",
    "drugEraCheckIncorrect.json",
    "emptyCorrelatedCriteria.json",
    "emptyDemographicCheckCorrect.json",
    "emptyInclusionRules.json",
    "emptyPrimaryCriteriaList.json",
    "inclusionRulesCheckValueIncorrect.json",
    "primaryCriteriaCheckValueIncorrect.json",
    "buildOptionsTest.json",
    "dupilumabExpression.json",
    "dupixentExpression.json",
    "vocabulary.json",
    "conceptSetList.json",
    "payerPlanCohortExpression.json",
]
for (root, dirs, files) in walkdir(joinpath(artifact"circe-be", "circe-be-1.9.3/src/test/resources"))
    for file in files
        endswith(file, ".json") || continue
        !endswith(file, "_PREP.json") && !endswith(file, "_VERIFY.json") || continue
        !in(file, invalid_circe_be_cohort_files) || continue
        @test test_unpack(joinpath(root, file))
    end
end

for dir in readdir(joinpath(artifact"PhenotypeLibrary", "PhenotypeLibrary-0.0.1/inst"), join = true)
    isdir(dir) || continue
    for file in readdir(dir, join = true)
        endswith(file, ".json") || continue
        @test test_unpack(file)
    end
end
