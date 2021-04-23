#!/usr/bin/env julia

using JavaCall
using Pkg.Artifacts

JavaCall.addClassPath(joinpath(artifact"CirceR", "CirceR-1.0.0/inst/java/*"))
JavaCall.addClassPath(joinpath(artifact"SqlRender", "SqlRender-1.7.0/inst/java/*"))
JavaCall.init(["-Xmx128M"])

const JavaCohortExpression =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpression")}

const JavaCohortExpressionQueryBuilder =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder")}

const JavaBuildExpressionQueryOptions =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder\$BuildExpressionQueryOptions")}

const JavaSqlRender =
    JavaObject{Symbol("org.ohdsi.sql.SqlRender")}

const JavaSqlTranslate =
    JavaObject{Symbol("org.ohdsi.sql.SqlTranslate")}

function JavaCohortToSql(cohort::AbstractString,
                         dialect::AbstractString,
                         parameters::AbstractDict{<:AbstractString, <:AbstractString})
    expr = jcall(JavaCohortExpression, "fromJson",
                 JavaCohortExpression, (JString,),
                 cohort)
    builder = JavaCohortExpressionQueryBuilder(())
    template = jcall(builder, "buildExpressionQuery",
                     JString, (JavaCohortExpression, JavaBuildExpressionQueryOptions),
                     expr, nothing)
    sql = jcall(JavaSqlRender, "renderSql",
                JString, (JString, Vector{JString}, Vector{JString}),
                template, collect(String, keys(parameters)), collect(String, values(parameters)))
    tr = jcall(JavaSqlTranslate, "translateSql",
               JString, (JString, JString),
               sql, dialect)
    replace(tr, "\r\n" => '\n')
end

JavaCohortToSql(cohort, dialect, parameters) =
    JavaCohortToSql(String(cohort),
                    String(dialect),
                    Dict{String, String}([string(key) => string(val)
                                          for (key, val) in pairs(parameters)]))

JavaCohortToSql(cohort;
                dialect = :postgresql,
                target_cohort_id = 0,
                generateStats = 0,
                vocabulary_database_schema = :public,
                cdm_database_schema = :public,
                results_database_schema = :public,
                target_database_schema = :public,
                target_cohort_table = :cohort,
                kws...) =
    JavaCohortToSql(cohort,
                    dialect,
                    (target_cohort_id = target_cohort_id,
                     generateStats = generateStats,
                     vocabulary_database_schema = vocabulary_database_schema,
                     cdm_database_schema = cdm_database_schema,
                     results_database_schema = results_database_schema,
                     target_database_schema = target_database_schema,
                     target_cohort_table = target_cohort_table,
                     kws...))

function usage()
    println("Usage: $PROGRAM_FILE [dialect=postgresql] [target_cohort_id=0] ... < cohort.json")
    exit(1)
end

const parameters = Dict{Symbol, String}()
for arg in ARGS
    occursin('=', arg) || usage()
    key, val = split(arg, '=', limit = 2)
    if startswith(key, "--")
        key = key[3:end]
    end
    key = replace(key, '-' => '_')
    parameters[Symbol(key)] = val
end

const cohort = read(stdin, String)

sql = JavaCohortToSql(cohort; parameters...)
println(sql)
