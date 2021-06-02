using ODBC
using Tables
using Dates

import FunSQL:
    FunSQL, SQLNode, Select, Get, From, Join, Lit, Group, Agg, Fun
import ..FunOHDSI:
    FunOHDSI,
    ConceptExpression, Concept, EmptyConcept, IncludeConcepts, ExcludeConcepts,
    ConceptSearch, ConceptFilter, ConceptParents, ConceptChildren,
    ConceptDescendants, ConceptAncestors, Source, translate

"""
Configure OHDSI query environment with source.

TODO(andreypopp): figure out how to make reactivity work with that...
"""
function configure(; params...)
    default_source[] = Source(; params...)
    nothing
end

default_source = Ref{Union{Source,Nothing}}(nothing)

"""
Compute result of an expression.
"""
function result(c::ConceptExpression; offset=1, limit=10, source=default_source[])
    rows = execute(translatewithinfo(c, source), source)
    # TODO(andreypopp): replace with ORDER BY ... OFFSET ... LIMIT ... once it
    # is implemented
    collect(Iterators.take(Iterators.drop(rows, offset - 1), limit))
end

"""
Compute statistics about an expression.
"""
function summary(c::ConceptExpression; source=default_source[])
    @assert source !== nothing
    q0 = translate(c, source)
    qstandard = q0 |>
        Join(:concept => From(source.model.concept),
             Get.concept_id .== Get.concept.concept_id) |>
        Group() |>
        Select(
               :total => Agg.count(Get.concept_id),
               :standard => Agg.count(filter = Get.concept.standard_concept .== Lit("S")),
               :nonstandard => Agg.count(filter = Fun."is null"(Get.concept.standard_concept)),
               :classification => Agg.count(filter = Get.concept.standard_concept .== Lit("C")),
              )
    qvocabulary = q0 |>
        Join(:concept => From(source.model.concept),
             Get.concept_id .== Get.concept.concept_id) |>
        Group(Get.concept.vocabulary_id) |>
        Select(
               Get.vocabulary_id,
               Agg.count(),
              )
    standard = execute(qstandard, source)[1]
    vocabulary = execute(qvocabulary, source)
    (
     total=standard.total,
     standard=(
               standard=standard.standard,
               nonstandard=standard.nonstandard,
               classification=standard.classification,
              ),
     vocabulary=Dict((row.vocabulary_id, row.count) for row in vocabulary),
    )
end

function execute(query::SQLNode, source)
    sql = FunSQL.render(query, dialect = source.dialect)
    conn = ODBC.Connection(source.dsn)
    try
        cur = DBInterface.execute(conn, sql)
        Tables.rowtable(cur)
    finally
        DBInterface.close!(conn)
    end
end

function translatewithinfo(c::ConceptExpression, source::Source)
    @assert source !== nothing
    translate(c, source) |>
    Join(:info => From(source.model.concept),
        Get.concept_id .== Get.info.concept_id) |>
    Select(
            Get.info.concept_id,
            Get.info.concept_name,
            Get.info.domain_id,
            Get.info.vocabulary_id,
            Get.info.concept_class_id,
            Get.info.standard_concept,
            Get.info.concept_code,
            Get.info.valid_start_date,
            Get.info.valid_end_date,
            Get.info.invalid_reason,
            )
end

tojs(::EmptyConcept, ::Source) =
    nothing

function tojs(expr::Concept, source::Source)
    q = translatewithinfo(expr, source)
    sql = FunSQL.render(q, dialect = source.dialect)
    conn = ODBC.Connection(source.dsn)
    cur = DBInterface.execute(conn, sql)
    rows = [row for row in Tables.rowtable(cur)]
    get(rows, 1, nothing)
end

function derive_tojs(stype::Type{<:ConceptExpression})
    name = String(stype.name.name)
    args = [:(__type=$name)]
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
        if type <: ConceptExpression
            push!(args, :($name=tojs(expr.$name, source)))
        elseif type <: Vector{<:ConceptExpression}
            push!(args, :($name=[tojs(e, source) for e in expr.$name]))
        else
            push!(args, :($name=expr.$name))
        end
    end
    eval(quote
        tojs(expr::$stype, source::FunOHDSI.Source) = (;$(args...))
    end)
end

derive_tojs(ConceptSearch)
derive_tojs(ConceptFilter)
derive_tojs(IncludeConcepts)
derive_tojs(ExcludeConcepts)
derive_tojs(ConceptParents)
derive_tojs(ConceptChildren)
derive_tojs(ConceptAncestors)
derive_tojs(ConceptDescendants)

function __init__()
    haspluto = hasproperty(Main, :PlutoRunner)

    if haspluto
        eval(quote
            Main.PlutoRunner.pluto_show(expr::ConceptExpression) =
                tojs(expr, default_source[]),
                MIME"application/vnd.ohdsi.conceptexpression+object"()
        end)
    end
end
