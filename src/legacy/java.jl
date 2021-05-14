using Pkg.Artifacts

const java_initialized = Ref(false)

function initialize_java()
    if !java_initialized[]
        @eval using JavaCall
        Base.invokelatest() do
            JavaCall.addClassPath(joinpath(artifact"CirceR", "CirceR-1.0.0/inst/java/*"))
            JavaCall.addClassPath(joinpath(artifact"SqlRender", "SqlRender-1.7.0/inst/java/*"))
            JavaCall.init(["-Xmx128M"])
        end
        java_initialized[] = true
    end
end

function render_sql(template::AbstractString, parameters::AbstractDict{<:AbstractString, <:AbstractString})
    SqlRender =
        JavaObject{Symbol("org.ohdsi.sql.SqlRender")}
    jcall(SqlRender, "renderSql",
          JString, (JString, Vector{JString}, Vector{JString}),
          template, collect(String, keys(parameters)), collect(String, values(parameters)))
end

function translate_sql(sql::AbstractString, dialect::AbstractString)
    SqlTranslate =
        JavaObject{Symbol("org.ohdsi.sql.SqlTranslate")}
    if dialect == "sqlserver"
        dialect = "sql server"
    end
    jcall(SqlTranslate, "translateSql",
          JString, (JString, JString),
          sql, dialect)
end

function build_expression_query(cohort::AbstractString)
    CohortExpression =
        JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpression")}
    CohortExpressionQueryBuilder =
        JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder")}
    BuildExpressionQueryOptions =
        JavaObject{Symbol("org.ohdsi.circe.cohortdefinition.CohortExpressionQueryBuilder\$BuildExpressionQueryOptions")}
    expr = jcall(CohortExpression, "fromJson",
                 CohortExpression, (JString,),
                 cohort)
    builder = CohortExpressionQueryBuilder(())
    jcall(builder, "buildExpressionQuery",
          JString, (CohortExpression, BuildExpressionQueryOptions),
          expr, nothing)
end

function cohort_to_sql(cohort::AbstractString,
                       dialect::AbstractString,
                       parameters::AbstractDict{<:AbstractString, <:AbstractString})
    if !java_initialized[]
        initialize_java()
        return Base.invokelatest(cohort_to_sql, cohort, dialect, parameters)
    end
    template = build_expression_query(cohort)
    sql = render_sql(template, parameters)
    tr = translate_sql(sql, dialect)
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

