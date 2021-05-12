module Legacy

using JavaCall
using Pkg.Artifacts

const initialized = Ref(false)

function initialize()
    if !initialized[]
        JavaCall.addClassPath(joinpath(artifact"CirceR", "CirceR-1.0.0/inst/java/*"))
        JavaCall.addClassPath(joinpath(artifact"SqlRender", "SqlRender-1.7.0/inst/java/*"))
        JavaCall.init(["-Xmx128M"])
        initialized[] = true
    end
end

const CohortExpression =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpression")}

const CohortExpressionQueryBuilder =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder")}

const BuildExpressionQueryOptions =
    JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder\$BuildExpressionQueryOptions")}

const SqlRender =
    JavaObject{Symbol("org.ohdsi.sql.SqlRender")}

const SqlTranslate =
    JavaObject{Symbol("org.ohdsi.sql.SqlTranslate")}

function cohort_to_sql(cohort::AbstractString,
                       dialect::AbstractString,
                       parameters::AbstractDict{<:AbstractString, <:AbstractString})
    initialize()
    if dialect == "sqlserver"
        dialect = "sql server"
    end
    expr = jcall(CohortExpression, "fromJson",
                 CohortExpression, (JString,),
                 cohort)
    builder = CohortExpressionQueryBuilder(())
    template = jcall(builder, "buildExpressionQuery",
                     JString, (CohortExpression, BuildExpressionQueryOptions),
                     expr, nothing)
    sql = jcall(SqlRender, "renderSql",
                JString, (JString, Vector{JString}, Vector{JString}),
                template, collect(String, keys(parameters)), collect(String, values(parameters)))
    tr = jcall(SqlTranslate, "translateSql",
               JString, (JString, JString),
               sql, dialect)
    replace(tr, "\r\n" => '\n')
end

cohort_to_sql(cohort, dialect, parameters) =
    cohort_to_sql(String(cohort),
                  String(dialect),
                  Dict{String, String}([string(key) => string(val)
                                        for (key, val) in pairs(parameters)]))

cohort_to_sql(cohort;
              dialect = :postgresql,
              target_cohort_id = 0,
              generateStats = 0,
              vocabulary_database_schema = :public,
              cdm_database_schema = :public,
              results_database_schema = :public,
              target_database_schema = :public,
              target_cohort_table = :cohort,
              kws...) =
    cohort_to_sql(cohort,
                  dialect,
                  (target_cohort_id = target_cohort_id,
                   generateStats = generateStats,
                   vocabulary_database_schema = vocabulary_database_schema,
                   cdm_database_schema = cdm_database_schema,
                   results_database_schema = results_database_schema,
                   target_database_schema = target_database_schema,
                   target_cohort_table = target_cohort_table,
                   kws...))

end
