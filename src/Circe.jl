module Circe

import Base: isempty, parse

unpack_string!(data::Dict, key::String) =
    pop!(data, key)

unpack_string!(data::Dict, key::String, default) =
    haskey(data, key) ? unpack_string!(data, key) : default

function unpack_scalar!(data::Dict, key::String, type::Type)
    value = pop!(data, key)
    if value isa String
        return parse(type, value)
    end
    @assert value isa type
    return value
end

unpack_scalar!(data::Dict, key::String, type::Type, default) =
    haskey(data, key) ? unpack_scalar!(data, key, type) : default

function unpack_struct!(data::Dict, key::String, type::Type)
    bucket = data[key]
    retval = type(bucket)
    if isempty(bucket)
        delete!(data, key)
    end
    return retval
end

unpack_struct!(data::Dict, key::String, type::Type, default) =
    haskey(data, key) ? unpack_struct!(data, key, type) : default

function unpack_vector!(data::Dict, key::String, type::Type)
    remain = Dict[]
    retval = type[]
    for item in get(data, key, Dict[])
        push!(retval, type(item))
        if !isempty(item)
            push!(remain, item)
        end
    end
    if isempty(remain)
        delete!(data, key)
    else
        data[key] = remain
    end
    return retval
end

struct Criteria
    Criteria(data::Dict) = new()
end

struct Window
    Window(data::Dict) = new()
end

struct CriteriaColumn
    CriteriaColumn(data::Dict) = new()
end

@enum OccurrenceType EXACTLY=0 AT_MOST=1 AT_LEAST=2
Base.parse(::Type{OccurrenceType}, s::String) =
    s == "0" ? EXACTLY :
         "1" ? AT_MOST :
         "2" ? AT_LEAST :
         throw(DomainError(s, "Unknown Occurrence Type"))

struct Occurrence
    type::OccurrenceType
    Occurrence(data::Dict) = new(
       unpack_scalar!(data, "Type", OccurrenceType),
       unpack_scalar!(data, "Count", Int),
       unpack_scalar!(data, "IsDistinct", Bool),
       unpack_struct!(data, "CountColumn", CriteriaColumn))
end

struct CorrelatedCriteria
    criteria::Criteria
    end_window::Window
    ignore_observation_period::Bool
    occurrence::Occurrence
    restrict_visit::Bool
    start_window::Window

    CorrelatedCriteria(data::Dict) = new(
      unpack_struct!(data, "AdditionalCriteria", Criteria),
      unpack_struct!(data, "EndWindow", Window),
      unpack_scalar!(data, "IgnoreObservationPeriod", Bool, false),
      unpack_struct!(data, "Occurrence", Occurrence),
      unpack_scalar!(data, "RestrictVisit", Bool, false),
      unpack_scalar!(data, "StartWindow", Window))
end

struct DemographicCriteria
    DemographicCriteria(data::Dict) = new()
end

struct CriteriaGroup
    count::Union{Int, Nothing}
    correlated_criteria::Vector{CorrelatedCriteria}
    demographic_criteria::Vector{DemographicCriteria}
    groups::Vector{CriteriaGroup}
    type::Union{String, Nothing}

    CriteriaGroup(data::Dict) = new(
      unpack_scalar!(data, "Count", Int, nothing),
      unpack_vector!(data, "CriteriaList", CorrelatedCriteria),
      unpack_vector!(data, "DemographicCriteriaList", DemographicCriteria),
      unpack_vector!(data, "Groups", CriteriaGroup),
      unpack_string!(data, "Type", nothing))
end

isempty(g::CriteriaGroup) =
    isempty(d.correlated_criteria) &&
    isempty(d.demographic_criteria) &&
    isempty(d.groups)


struct ObservationFilter
    ObservationFilter(data::Dict) = new()
end

struct ResultLimit
    ResultLimit(data::Dict) = new()
end

struct CollapseSettings
    collapse_type::String
    era_pad::Int

    CollapseSettings(data::Dict) = new(
      unpack_string!(data, "CollapseType"),
      unpack_scalar!(data, "EraPad", Int, 0))
end

struct Period
    Period(data::Dict) = new()
end

struct ConceptSet
    ConceptSet(data::Dict) = new()
end

abstract type EndStrategy end;

struct CustomEraStrategy <: EndStrategy
    CustomEraEndStrategy(data::Dict) = new()
end

struct DateOffsetStrategy <: EndStrategy
    offset::Integer
    date_field::String

    DateOffsetStrategy(data::Dict) = new(
      unpack_scalar!(data, "Offset", Int),
      unpack_string!(data, "DateField"))
end

function EndStrategy(data::Dict)
    if haskey(data, "DateOffset")
        (key, type) = ("DateOffset", DateOffsetStrategy)
    else
        (key, type) = ("CustomEra", CustomEraStrategy)
    end
    subdata = data[key]
    retval = type(subdata)
    if isempty(subdata)
        delete!(data, key)
    end
    return retval
end

struct InclusionRule
    InclusionRule(data::Dict) = new()
end

struct PrimaryCriteria
    criteria_list::Vector{Criteria}
    observation_window::ObservationFilter
    primary_limit::ResultLimit

    PrimaryCriteria(data::Dict) = new()
end

struct CohortExpression
    additional_criteria::Union{CriteriaGroup, Nothing}
    censor_window::Period
    censoring_criteria::Vector{Criteria}
    collapse_settings::CollapseSettings
    concept_sets::Vector{ConceptSet}
    end_strategy::EndStrategy
    expression_limit::ResultLimit
    inclusion_rules::Vector{InclusionRule}
    primary_criteria::PrimaryCriteria
    qualified_limit::ResultLimit
    title::Union{String, Nothing}
    version_range::Union{String, Nothing}

    CohortExpression(data::Dict) = new(
      unpack_struct!(data, "AdditionalCritiera", CriteriaGroup, nothing),
      unpack_struct!(data, "CensorWindow", Period),
      unpack_vector!(data, "CensoringCriteria", Criteria),
      unpack_struct!(data, "CollapseSettings", CollapseSettings),
      unpack_vector!(data, "ConceptSets", ConceptSet),
      unpack_struct!(data, "EndStrategy", EndStrategy),
      unpack_struct!(data, "ExpressionLimit", ResultLimit),
      unpack_vector!(data, "InclusionRules", InclusionRule),
      unpack_struct!(data, "PrimaryCriteria", PrimaryCriteria),
      unpack_struct!(data, "QualifiedLimit", ResultLimit),
      unpack_string!(data, "Title", nothing),
      unpack_string!(data, "cdmVersionRange", nothing)
    )

end

end
