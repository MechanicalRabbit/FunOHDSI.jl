
abstract type ConceptExpression
end

struct Concept <: ConceptExpression
    id::Int
end

struct ConceptSearch <: ConceptExpression
    name::Union{String, Nothing}
end

struct ConceptUnion <: ConceptExpression
    exprs::Vector{ConceptExpression}
end

struct ConceptDifference <: ConceptExpression
    expr1::ConceptExpression
    expr2::ConceptExpression
end

struct ExcludeConcept <: ConceptExpression
    expr::ConceptExpression
end

struct ConceptAncestors <: ConceptExpression
    expr::ConceptExpression
end

struct ConceptDescendants <: ConceptExpression
    expr::ConceptExpression
end

struct ConceptParents <: ConceptExpression
    expr::ConceptExpression
end

struct ConceptChildren <: ConceptExpression
    expr::ConceptExpression
end

normalize(::ConceptExpression)::ConceptExpression =
    error()

materialize(::ConceptExpression, source::Source)::Vector{Concept} =
    error()

translate(::ConceptExpression, source::Source)::SQLNode =
    error()

struct ConceptSummary
end

summary(::ConceptExpresssion, source::Source)::ConceptSummary =
    error()

