#!/usr/bin/env julia

using Test

using FunOHDSI.Legacy: unpack!, translate
using JSON
using PrettyPrinting
using Pkg.Artifacts

should_exit_on_error = false
should_test_unpack = false
should_test_translate = false
should_test_all = true
cohort = nothing
for arg in ARGS
    if arg == "--exit-on-error"
        global should_exit_on_error = true
    elseif arg == "--test-unpack"
        global should_test_unpack = true
        global should_test_all = false
    elseif arg == "--test-translate"
        global should_test_translate = true
        global should_test_all = false
    elseif startswith(arg, "--cohort=")
        global cohort = arg[length("--cohort=")+1:end]
    else
        error("invalid argument $arg")
    end
end

macro testset_unless_exit_on_error(name, ex)
    if should_exit_on_error
        esc(ex)
    else
        esc(:(@testset $name $ex))
    end
end

const invalid_circe_be_cohort_files = [
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
function test_each_circe_cohort(f)
    for (root, dirs, files) in walkdir(joinpath(artifact"circe-be", "circe-be-1.9.3/src/test/resources"))
        for file in files
            cohort == nothing || contains(file, cohort) || continue
            endswith(file, ".json") || continue
            !endswith(file, "_PREP.json") && !endswith(file, "_VERIFY.json") || continue
            !in(file, invalid_circe_be_cohort_files) || continue
            @test f(joinpath(root, file))
        end
    end
end

function test_each_phenotype_cohort(f)
    for dir in readdir(joinpath(artifact"PhenotypeLibrary", "PhenotypeLibrary-0.0.1/inst"), join = true)
        isdir(dir) || continue
        for file in readdir(dir, join = true)
            cohort == nothing || contains(file, cohort) || continue
            endswith(file, ".json") || continue
            @test f(file)
        end
    end
end

@testset_unless_exit_on_error "FunOHDSI" begin

if should_test_unpack || should_test_all
    @testset_unless_exit_on_error "unpack!()" begin
        function test_unpack(file)
            println('-' ^ 80)
            println(file)
            data = JSON.parsefile(file)
            expr = unpack!(data)
            pprintln(expr)
            pprintln(data)
            isempty(data)
        end

        test_each_circe_cohort(test_unpack)
        test_each_phenotype_cohort(test_unpack)
    end
end

if should_test_translate || should_test_all
    @testset_unless_exit_on_error "translate()" begin
        function test_translate(file)
            println('-' ^ 80)
            println(file)
            data = JSON.parsefile(file)
            expr = unpack!(data)
            @assert isempty(data)
            pprintln(expr)
            sql = translate(expr, dialect = :postgresql)
            println(sql)
            true
        end

        test_each_circe_cohort(test_translate)
        test_each_phenotype_cohort(test_translate)
    end
end

end
