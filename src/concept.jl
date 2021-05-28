using FunSQL:
    SQLNode, Append, From, Fun, Get, Group, Join, Select, Where, render
using ODBC
using Tables

"""
`ConceptExpression` represents a transformation of a concept set.

Each concept expression is a function that maps a concept set to a concept set.
With each expression, we can associate a canonical concept set obtained by
applying the function to an empty set.

# Examples

```jldoctest
julia> c = IncludeConcepts(
               Concept(1),
               Concept(2) |> ConceptDescendants(),
               Concept(3)) |>
           ExcludeConcepts(
               Concept(4),
               Concept(5) |> ConceptDescendants());

julia> materialize(c, Source());
```
"""
abstract type ConceptExpression
end

(c::ConceptExpression)(c′) =
    c(convert(ConceptExpression, c′))

struct Concept <: ConceptExpression
    id::Int

    Concept(; id) =
        new(id)
end

Concept(id) =
    Concept(id = id)

Base.convert(::Type{ConceptExpression}, id::Integer) =
    Concept(id)

(c::Concept)(c′::ConceptExpression) =
    c

struct ConceptSearch <: ConceptExpression
    search::String

    ConceptSearch(; search) =
        new(search)
end

ConceptSearch(search) =
    ConceptSearch(search = search)

(c::ConceptSearch)(c′::ConceptExpression) =
    c

standard_values = Set([:standard, :nonstandard, :classification])

struct ConceptFilter <: ConceptExpression
    base::ConceptExpression
    standard::Union{Symbol, Nothing}
    vocabulary::Union{Nothing,Vector{String}}

    function ConceptFilter(; base=nothing, standard=nothing, vocabulary=nothing)
        if standard !== nothing && standard ∉ standard_values
            throw(ArgumentError("invalid standard filter: $standard"))
        end
        new(base, standard, vocabulary)
    end
end

(c::ConceptFilter)(c′::ConceptExpression) =
    ConceptFilter(
                  base = c.base(c′),
                  standard = c.standard,
                  vocabulary = c.vocabulary
                 )

struct EmptyConcept <: ConceptExpression
end

Base.convert(::Type{ConceptExpression}, ::Nothing) =
    EmptyConcept()

(c::EmptyConcept)(c′::ConceptExpression) =
    c′

struct IncludeConcepts <: ConceptExpression
    base::ConceptExpression
    exprs::Vector{ConceptExpression}

    IncludeConcepts(; base = nothing, exprs) =
        new(base, exprs)
end

IncludeConcepts(exprs...) =
    IncludeConcepts(exprs = ConceptExpression[exprs...])

(c::IncludeConcepts)(c′::ConceptExpression) =
    IncludeConcepts(base = c.base(c′), exprs = c.exprs)

struct ExcludeConcepts <: ConceptExpression
    base::ConceptExpression
    exprs::Vector{ConceptExpression}

    ExcludeConcepts(; base = nothing, exprs) =
        new(base, exprs)
end

ExcludeConcepts(exprs...) =
    ExcludeConcepts(exprs = ConceptExpression[exprs...])

(c::ExcludeConcepts)(c′::ConceptExpression) =
    ExcludeConcepts(base = c.base(c′), exprs = c.exprs)

struct ConceptParents <: ConceptExpression
    base::ConceptExpression

    ConceptParents(; base = nothing) =
        new(base)
end

(c::ConceptParents)(c′::ConceptExpression) =
    ConceptParents(base = c.base(c′))

struct ConceptChildren <: ConceptExpression
    base::ConceptExpression

    ConceptChildren(; base = nothing) =
        new(base)
end

(c::ConceptChildren)(c′::ConceptExpression) =
    ConceptChildren(base = c.base(c′))

struct ConceptAncestors <: ConceptExpression
    base::ConceptExpression

    ConceptAncestors(; base = nothing) =
        new(base)
end

(c::ConceptAncestors)(c′::ConceptExpression) =
    ConceptAncestors(base = c.base(c′))

struct ConceptDescendants <: ConceptExpression
    base::ConceptExpression

    ConceptDescendants(; base = nothing) =
        new(base)
end

(c::ConceptDescendants)(c′::ConceptExpression) =
    ConceptDescendants(base = c.base(c′))

normalize(::ConceptExpression)::ConceptExpression =
    error()

function materialize(c::ConceptExpression, source::Source)
    q = translate(c, source)
    sql = render(q, dialect = source.dialect)
    conn = ODBC.Connection(source.dsn)
    cur = DBInterface.execute(conn, sql)
    Concept[Concept(row.concept_id) for row in Tables.rowtable(cur)]
end

struct TranslateConceptContext
    dialect::Symbol
    model::Model
end

function translate(c::ConceptExpression, source::Source)::SQLNode
    ctx = TranslateConceptContext(source.dialect, source.model)
    q = translate(c, ctx)
    q |> Group(Get.concept_id)
end

translate(c::Concept, ctx::TranslateConceptContext) =
    From(ctx.model.concept) |>
    Where(Get.concept_id .== c.id)

translate(c::ConceptSearch, ctx::TranslateConceptContext) =
    From(ctx.model.concept) |>
    Where(Fun.ilike(Get.concept_name, "%" * c.search * "%"))

function translate(c::ConceptFilter, ctx::TranslateConceptContext)
    q = translate(c.base, ctx)
    if c.standard !== nothing
        q = q |> Where(if c.standard == :standard
                           Get.standard_concept .== "S"
                        elseif c.standard == :classification
                           Get.standard_concept .== "C"
                        else
                            Fun."is null"(Get.standard_concept)
                        end)
    end
    if c.vocabulary !== nothing && length(c.vocabulary) > 0
        q = q |> Where(Fun."or"(((Get.vocabulary_id .== v) for v in c.vocabulary)...))
    end
    q
end

translate(::EmptyConcept, ctx::TranslateConceptContext) =
    From(ctx.model.concept) |>
    Where(false)

translate(c::IncludeConcepts, ctx::TranslateConceptContext) =
    translate(c.base, ctx) |> Append(list = [translate(e, ctx) for e in c.exprs])

function translate(c::ExcludeConcepts, ctx::TranslateConceptContext)
    q = translate(c.base, ctx)
    for e in c.exprs
        eq = translate(e, ctx)
        q = q |>
            Join(:exclude => eq,
                 Get.concept_id .== eq.concept_id,
                 left = true) |>
            Where(Fun."is null"(eq.concept_id))
    end
    q
end

function translate(c::ConceptDescendants, ctx::TranslateConceptContext)
    q = translate(c.base, ctx)
    q = q |>
        Append(
            From(ctx.model.concept) |>
            Where(Fun."is null"(Get.invalid_reason)) |>
            Join(ctx.model.concept_ancestor,
                 Get.concept_id .== Get.descendant_concept_id) |>
            Where(Fun.in(Get.ancestor_concept_id,
                         translate(c.base, ctx) |> Select(Get.concept_id))))
    q
end

function translate(c::ConceptAncestors, ctx::TranslateConceptContext)
    q = translate(c.base, ctx)
    q = q |>
        Append(
            From(ctx.model.concept) |>
            Where(Fun."is null"(Get.invalid_reason)) |>
            Join(ctx.model.concept_ancestor,
                 Get.concept_id .== Get.ancestor_concept_id) |>
            Where(Fun.in(Get.descendant_concept_id,
                         translate(c.base, ctx) |> Select(Get.concept_id))))
    q
end

function translate(c::ConceptChildren, ctx::TranslateConceptContext)
    From(ctx.model.concept) |>
    Where(Fun."is null"(Get.invalid_reason)) |>
    Join(ctx.model.concept_ancestor,
         Get.concept_id .== Get.descendant_concept_id) |>
    Where(Get.descendant_concept_id .!= Get.ancestor_concept_id) |>
    Where(Fun.in(Get.ancestor_concept_id,
                 translate(c.base, ctx) |> Select(Get.concept_id))) |>
    Where(Get.max_levels_of_separation .== 1)
end

function translate(c::ConceptParents, ctx::TranslateConceptContext)
    From(ctx.model.concept) |>
    Where(Fun."is null"(Get.invalid_reason)) |>
    Join(ctx.model.concept_ancestor,
         Get.concept_id .== Get.ancestor_concept_id) |>
    Where(Get.descendant_concept_id .!= Get.ancestor_concept_id) |>
    Where(Fun.in(Get.descendant_concept_id,
                 translate(c.base, ctx) |> Select(Get.concept_id))) |>
    Where(Get.max_levels_of_separation .== 1)
end

struct ConceptSummary
end

summary(::ConceptExpression, source::Source)::ConceptSummary =
    error()
