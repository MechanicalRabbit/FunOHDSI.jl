#!/usr/bin/env julia

using Test

using FunOHDSI: Source, initialize_java, cohort_to_sql
using OHDSICohortExpressions: unpack!, translate
using FunSQL: render, As, Select, Get, From, Fun, Join, Where, Group, Agg
using JSON
using PrettyPrinting
using Pkg.Artifacts
using ODBC
using DataFrames
using StringEncodings

should_exit_on_error = false
should_test_unpack = false
should_test_translate = false
should_test_result = false
should_test_all = true
cohort = nothing
should_show_expr = false
should_show_sql = false
for arg in ARGS
    if arg == "--exit-on-error"
        global should_exit_on_error = true
    elseif arg == "--test-unpack"
        global should_test_unpack = true
        global should_test_all = false
    elseif arg == "--test-translate"
        global should_test_translate = true
        global should_test_all = false
    elseif arg == "--test-result"
        global should_test_translate = true
        global should_test_result = true
        global should_test_all = false
    elseif startswith(arg, "--cohort=")
        global cohort = arg[length("--cohort=")+1:end]
    elseif arg == "--show-expr"
        global should_show_expr = true
    elseif arg == "--show-sql"
        global should_show_sql = true
    else
        error("invalid argument $arg")
    end
end

if should_test_result
    initialize_java()
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
    for (root, dirs, files) in walkdir(joinpath(artifact"circe-be", "circe-be-1.9.4/src/test/resources"))
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
            if should_show_expr
                pprintln(expr)
                pprintln(data)
            end
            isempty(data)
        end

        test_each_circe_cohort(test_unpack)
        test_each_phenotype_cohort(test_unpack)
    end
end

if should_test_translate || should_test_all
    source = should_test_result ? Source() : nothing
    dialect = source !== nothing ? source.dialect : :postgresql

    @testset_unless_exit_on_error "translate()" begin
        function test_translate(file)
            println('-' ^ 80)
            println(file)
            raw = read(file)
            json = decode(raw, "latin1")
            data = JSON.parse(json)
            expr = unpack!(data)
            @assert isempty(data)
            if should_show_expr
                pprintln(expr)
            end
            sql = translate(expr, dialect = dialect, cohort_definition_id = 1)
            if should_show_sql
                println(sql)
            end
            source !== nothing || return true
            conn = ODBC.Connection(source.dsn)
            @time DBInterface.execute(conn, sql)
            sql′ = cohort_to_sql(json, dialect = dialect)
            if should_show_sql
                println(sql′)
            end
            @time DBInterface.execute(conn, sql′)
            q = From(source.model.cohort) |>
                Group(Get.cohort_definition_id) |>
                Select(Get.cohort_definition_id, Agg.count())
            total = DataFrame(DBInterface.execute(conn, render(q, dialect = dialect)))
            println(total)
            q = From(source.model.cohort) |>
                Where(Get.cohort_definition_id .== 1) |>
                As(:a) |>
                Join(From(source.model.cohort) |>
                     Where(Get.cohort_definition_id .== 0) |>
                     As(:b),
                     Fun.and(Get.a.subject_id .== Get.b.subject_id,
                             Get.a.cohort_start_date .== Get.b.cohort_start_date,
                             Get.a.cohort_end_date .== Get.b.cohort_end_date),
                     left = true, right = true) |>
                Where(Fun.or(Fun."is null"(Get.a.subject_id),
                             Fun."is null"(Get.b.subject_id))) |>
                Select(:subject_id => Fun.coalesce(Get.a.subject_id, Get.b.subject_id),
                       :start_date => Fun.coalesce(Get.a.cohort_start_date, Get.b.cohort_start_date),
                       :end_date => Fun.coalesce(Get.a.cohort_end_date, Get.b.cohort_end_date),
                       :definition_id => Fun.coalesce(Get.a.cohort_definition_id, Get.b.cohort_definition_id))
            sql = render(q, dialect = dialect)
            diff = DataFrame(DBInterface.execute(conn, sql))
            sort!(diff)
            println(diff)
            isempty(diff)
        end

        #test_each_circe_cohort(test_translate)
        test_each_phenotype_cohort(test_translate)
    end
end

end
