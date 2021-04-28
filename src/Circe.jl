module Circe

import Base: isempty

unpack_string!(data::Dict, key::String) =
    pop!(data, key)

unpack_string!(data::Dict, key::String, default) =
    haskey(data, key) ? string(pop!(data, key)) : default

unpack_scalar!(data::Dict, key::String, type::Type, default) =
    haskey(data, key) ? parse(type, pop!(data, key)) : default

function unpack_struct!(data::Dict, key::String, type::Type)
    if !haskey(data, key)
        return type(Dict())
    end
    bucket = data[key]
    retval = type(bucket)
    if isempty(bucket)
        delete!(data, key)
    end
    return retval
end

function unpack_vector!(data::Dict, key::String, type::Type)
    remain = Dict[]
    retval = type[]
    for item in get(data, key, Dict[])
        push!(retval, unpack_struct!(item, key, type))
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

struct Occurrence
    Occurrence(data::Dict) = new()
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
    count::Union{Integer, Nothing}
    correlated_criteria::Vector{CorrelatedCriteria}
    demographic_criteria::Vector{DemographicCriteria}
    groups::Vector{CriteriaGroup}
    type::Union{String, Nothing}

    CriteriaGroup(data::Dict) = new(
      unpack_scalar!(data, "Count", Int, nothing),
      unpack_vector!(data, "CriteriaList", CorrelatedCriteria),
      unpack_vector!(data, "DemographicCriteriaList", DemographicCriteria),
      unpack_vector!(data, "Groups", CriteriaGroup),
      unpack_string!(data, "Type", nothing)
    )
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
    CollapseSettings(data::Dict) = new()
end

struct Period
    Period(data::Dict) = new()
end

struct ConceptSet
    ConceptSet(data::Dict) = new()
end

struct EndStrategy
    EndStrategy(data::Dict) = new()
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
    additional_criteria::CriteriaGroup
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
      unpack_struct!(data, "AdditionalCritiera", CriteriaGroup),
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
