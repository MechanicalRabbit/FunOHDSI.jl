module Circe

import Base: isempty, parse

abstract type Expression end;

unpack_string!(data::Dict, key::String) =
    pop!(data, key)

unpack_string!(data::Dict, key::String, default) =
    haskey(data, key) ?
        something(unpack_string!(data, key), default) :
        default

function unpack_scalar!(data::Dict, key::String, type::Type)
    value = pop!(data, key)
    if value isa String
        return parse(type, value)
    end
    return type(value)
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

struct DateRange
    value::String
    op::String
    extent::String

    DateRange(data::Dict) = new()

end

struct TextFilter
    text::String
    op::String

    TextFilter(data::Dict) = new()
end

struct NumericRange
    value::Number
    op::String
    extent::Union{Number, Nothing}

    NumericRange(data::Dict) = new(
      unpack_scalar!(data, "Value", Number),
      unpack_string!(data, "Op"),
      unpack_scalar!(data, "Extent", Number, nothing))
end

@enum InvalidReasonFlag UNKNOWN_REASON VALID INVALID
InvalidReasonFlag(::Nothing) = UNKNOWN_REASON
Base.parse(::Type{InvalidReasonFlag}, s::Union{String, Nothing}) =
    s == "V" ? VALID :
    s == "D" ? INVALID :
    s == "U" ? INVALID :
    isnothing(s) ? UNKNOWN_REASON :
         throw(DomainError(s, "Unknown Invalid Reason Flag"))

@enum StandardConceptFlag UNKNOWN_STANDARD STANDARD NON_STANDARD CLASSIFICATION
StandardConceptFlag(::Nothing) = UNKNOWN_STANDARD
Base.parse(::Type{StandardConceptFlag}, s::Union{String, Nothing}) =
    s == "N" ? NON_STANDARD :
    s == "S" ? STANDARD :
    s == "C" ? CLASSIFICATION :
    isnothing(s) ? UNKNOWN_STANDARD :
         throw(DomainError(s, "Unknown Standard Concept Flag"))

struct Concept
    concept_class_id::String
    concept_code::String
    concept_id::Int
    concept_name::String
    domain_id::String
    invalid_reason::InvalidReasonFlag
    invalid_reason_caption::String
    standard_concept::StandardConceptFlag
    standard_concept_caption::String
    vocabulary_id::String

    function Concept(data::Dict)
       trans = (
       unpack_string!(data, "CONCEPT_CLASS_ID", ""),
       unpack_string!(data, "CONCEPT_CODE"),
       unpack_scalar!(data, "CONCEPT_ID", Int),
       unpack_string!(data, "CONCEPT_NAME"),
       unpack_string!(data, "DOMAIN_ID"),
       unpack_scalar!(data, "INVALID_REASON", InvalidReasonFlag),
       unpack_string!(data, "INVALID_REASON_CAPTION"),
       unpack_scalar!(data, "STANDARD_CONCEPT", StandardConceptFlag),
       unpack_string!(data, "STANDARD_CONCEPT_CAPTION"),
       unpack_string!(data, "VOCABULARY_ID"))
       return new(trans...)
    end
end

abstract type Criteria <: Expression end;

function Base.getproperty(obj::Criteria, prop::Symbol)
    if prop in fieldnames(BaseCriteria)
        return getfield(obj.base, prop)
    else
        return getfield(obj, prop)
    end
end


struct Endpoint
    days::Union{Int, Nothing}
    coeff::Union{Int, Nothing}

    Endpoint(data::Dict) = new(
      unpack_scalar!(data, "Days", Int, nothing),
      unpack_scalar!(data, "Coeff", Int, nothing))
end

struct Window
    start::Endpoint
    end_::Endpoint
    use_index_end::Union{Bool, Nothing}
    use_event_end::Union{Bool, Nothing}

    Window(data::Dict) = new(
      unpack_struct!(data, "Start", Endpoint),
      unpack_struct!(data, "End", Endpoint),
      unpack_scalar!(data, "UseIndexEnd", Bool, nothing),
      unpack_scalar!(data, "UseEventEnd", Bool, nothing))
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
    count::Int
    is_distinct::Bool
    count_column::Union{CriteriaColumn, Nothing}

    Occurrence(data::Dict) = new(
       unpack_scalar!(data, "Type", OccurrenceType),
       unpack_scalar!(data, "Count", Int),
       unpack_scalar!(data, "IsDistinct", Bool, false),
       unpack_struct!(data, "CountColumn", CriteriaColumn, nothing))
end

struct CorrelatedCriteria
    criteria::Union{Criteria, Nothing}
    end_window::Union{Window, Nothing}
    ignore_observation_period::Bool
    occurrence::Union{Occurrence, Nothing}
    restrict_visit::Bool
    start_window::Union{Window, Nothing}

    CorrelatedCriteria(data::Dict) = new(
      unpack_struct!(data, "Criteria", Criteria, nothing),
      unpack_struct!(data, "EndWindow", Window, nothing),
      unpack_scalar!(data, "IgnoreObservationPeriod", Bool, false),
      unpack_struct!(data, "Occurrence", Occurrence, nothing),
      unpack_scalar!(data, "RestrictVisit", Bool, false),
      unpack_struct!(data, "StartWindow", Window, nothing))
end

struct DemographicCriteria
    age::Union{NumericRange, Nothing}
    ethnicity::Vector{Concept}
    gender::Vector{Concept}
    occurrence_end_date::Union{DateRange, Nothing}
    occurrence_start_date::Union{DateRange, Nothing}
    race::Vector{Concept}

    DemographicCriteria(data::Dict) = new(
       unpack_struct!(data, "Age", NumericRange, nothing),
       unpack_vector!(data, "Ethnicity", Concept),
       unpack_vector!(data, "Gender", Concept),
       unpack_struct!(data, "OccurrenceEndDate", DateRange, nothing),
       unpack_struct!(data, "OccurrenceStartDate", DateRange, nothing),
       unpack_vector!(data, "Race", Concept))
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

struct ConceptSetItem
    concept::Concept
    is_excluded::Bool
    include_descendants::Bool
    include_mapped::Bool

    ConceptSetItem(data::Dict) = new(
      unpack_struct!(data, "concept", Concept),
      unpack_scalar!(data, "isExcluded", Bool, false),
      unpack_scalar!(data, "includeDescendants", Bool, false),
      unpack_scalar!(data, "includeMapped", Bool, false))
end

struct ConceptSet
    id::Int
    name::String
    items::Vector{ConceptSetItem}

    function ConceptSet(data::Dict)
        items = data["expression"]
        retval = new(
          unpack_scalar!(data, "id", Int),
          unpack_string!(data, "name"),
          unpack_vector!(items, "items", ConceptSetItem))
        if isempty(items)
           delete!(data, "expression")
        end
        return retval
    end
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
    name::String
    description::String
    expression::CriteriaGroup

    InclusionRule(data::Dict) = new(
      unpack_string!(data, "name"),
      unpack_string!(data, "description", ""),
      unpack_struct!(data, "expression", CriteriaGroup))
end

struct ObservationFilter
    prior_days::Int
    post_days::Int

    ObservationFilter(data::Dict) = new(
      unpack_scalar!(data, "PriorDays", Int, 0),
      unpack_scalar!(data, "PostDays", Int, 0))
end

struct ResultLimit
    type::String

    ResultLimit(data::Dict) = new(
      unpack_string!(data, "Type", "First"))
end

struct PrimaryCriteria
    criteria_list::Vector{Criteria}
    observation_window::ObservationFilter
    primary_limit::ResultLimit

    PrimaryCriteria(data::Dict) = new(
      unpack_vector!(data, "CriteriaList", Criteria),
      unpack_struct!(data, "ObservationWindow", ObservationFilter),
      unpack_struct!(data, "PrimaryCriteriaLimit", ResultLimit))
end

struct BaseCriteria
    age::Union{NumericRange, Nothing}
    codeset_id::Union{Int, Nothing}
    correlated_criteria::Union{CorrelatedCriteria, Nothing}
    first::Bool
    gender::Vector{Concept}
    occurrence_end_date::Union{DateRange, Nothing}
    occurrence_start_date::Union{DateRange, Nothing}
    provider_specality::Vector{Concept}
    visit_type::Vector{Concept}

    BaseCriteria(data::Dict) = new(
       unpack_struct!(data, "Age", NumericRange, nothing),
       unpack_scalar!(data, "CodesetId", Int, nothing),
       unpack_scalar!(data, "CorrelatedCriteria", CorrelatedCriteria, nothing),
       unpack_scalar!(data, "First", Bool, false),
       unpack_vector!(data, "Gender", Concept),
       unpack_struct!(data, "OccurrenceEndDate", DateRange, nothing),
       unpack_struct!(data, "OccurrenceStartDate", DateRange, nothing),
       unpack_vector!(data, "ProviderSpecialty", Concept),
       unpack_vector!(data, "VisitType", Concept))
end

struct UnknownCriteria <: Criteria
    UnknownCriteria(data::Dict) = new()
end

struct ConditionOccurrence <: Criteria
    base::BaseCriteria
    condition_source_concept::Union{Int, Nothing}
    condition_status::Vector{Concept}
    condition_type::Vector{Concept}
    condition_type_exclude::Bool
    stop_reason::Union{TextFilter, Nothing}

    ConditionOccurrence(data::Dict) = new(
       BaseCriteria(data),
       unpack_scalar!(data, "ConditionSourceConcept", Int, nothing),
       unpack_vector!(data, "ConditionStatus", Concept),
       unpack_vector!(data, "ConditionType", Concept),
       unpack_scalar!(data, "ConditionTypeExclude", Bool, false),
       unpack_struct!(data, "StopReason", TextFilter, nothing))
end

struct DrugExposure <: Criteria
    base::BaseCriteria
    drug_source_concept::Union{Int, Nothing}
    drug_type::Vector{Concept}
    drug_type_exclude::Bool
    refills::Union{NumericRange, Nothing}
    quantity::Union{NumericRange, Nothing}
    days_supply::Union{NumericRange, Nothing}
    route_concept::Vector{Concept}
    effective_drug_dose::Union{NumericRange, Nothing}
    dose_unit::Vector{Concept}
    lot_number::Union{TextFilter, Nothing}
    stop_reason::Union{TextFilter, Nothing}

    DrugExposure(data::Dict) = new(
       BaseCriteria(data),
       unpack_scalar!(data, "DrugSourceConcept", Int, nothing),
       unpack_vector!(data, "DrugType", Concept),
       unpack_scalar!(data, "DrugTypeExclude", Bool, false),
       unpack_struct!(data, "Refills", NumericRange, nothing),
       unpack_struct!(data, "Quantity", NumericRange, nothing),
       unpack_struct!(data, "DaysSupply", NumericRange, nothing),
       unpack_vector!(data, "RouteConcept", Concept),
       unpack_struct!(data, "EffectiveDrugDose", NumericRange, nothing),
       unpack_vector!(data, "DoseUnit", Concept),
       unpack_struct!(data, "LotNumber", TextFilter, nothing),
       unpack_struct!(data, "StopReason", TextFilter, nothing))
end

struct Measurement <: Criteria
    base::BaseCriteria
    observation_source_concept::Union{Int, Nothing}
    observation_type::Vector{Concept}
    observation_type_exclude::Bool
    abnormal::Union{Bool, Nothing}
    range_low::Union{NumericRange, Nothing}
    range_high::Union{NumericRange, Nothing}
    range_low_ratio::Union{NumericRange, Nothing}
    range_high_ratio::Union{NumericRange, Nothing}
    value_as_number::Union{NumericRange, Nothing}
    value_as_concept::Vector{Concept}
    operator::Vector{Concept}
    unit::Vector{Concept}

    Measurement(data::Dict) = new(
       BaseCriteria(data),
       unpack_scalar!(data, "MeasurementSourceConcept", Int, nothing),
       unpack_vector!(data, "MeasurementType", Concept),
       unpack_scalar!(data, "MeasurementTypeExclude", Bool, false),
       unpack_scalar!(data, "Abnormal", Bool, nothing),
       unpack_struct!(data, "RangeLow", NumericRange, nothing),
       unpack_struct!(data, "RangeHigh", NumericRange, nothing),
       unpack_struct!(data, "RangeLowRatio", NumericRange, nothing),
       unpack_struct!(data, "RangeHighRatio", NumericRange, nothing),
       unpack_struct!(data, "ValueAsNumber", NumericRange, nothing),
       unpack_vector!(data, "ValueAsConcept", Concept),
       unpack_vector!(data, "Operator", Concept),
       unpack_vector!(data, "Unit", Concept))
end


struct Observation <: Criteria
    base::BaseCriteria
    observation_source_concept::Union{Int, Nothing}
    observation_type::Vector{Concept}
    observation_type_exclude::Bool
    value_as_string::Union{TextFilter, Nothing}
    value_as_number::Union{NumericRange, Nothing}
    value_as_concept::Vector{Concept}
    qualifier::Vector{Concept}
    unit::Vector{Concept}

    Observation(data::Dict) = new(
       BaseCriteria(data),
       unpack_scalar!(data, "ObservationSourceConcept", Int, nothing),
       unpack_vector!(data, "ObservationType", Concept),
       unpack_scalar!(data, "ObservationTypeExclude", Bool, false),
       unpack_struct!(data, "ValueAsString", TextFilter, nothing),
       unpack_struct!(data, "ValueAsNumber", NumericRange, nothing),
       unpack_vector!(data, "ValueAsConcept", Concept),
       unpack_vector!(data, "Qualifier", Concept),
       unpack_vector!(data, "Unit", Concept))
end

struct ObservationPeriod <: Criteria
    base::BaseCriteria
    period_type::Vector{Concept}
    period_type_exclude::Bool
    period_start_date::Union{DateRange, Nothing}
    period_end_date::Union{DateRange, Nothing}
    period_length::Union{NumericRange, Nothing}
    age_at_start::Union{NumericRange, Nothing}
    age_at_end::Union{NumericRange, Nothing}
    user_defined_period::Union{Period, Nothing}

    ObservationPeriod(data::Dict) = new(
       BaseCriteria(data),
       unpack_vector!(data, "PeriodType", Concept),
       unpack_scalar!(data, "PeriodTypeExclude", Bool, false),
       unpack_struct!(data, "PeriodStartDate", DateRange, nothing),
       unpack_struct!(data, "PeriodEndDate", DateRange, nothing),
       unpack_struct!(data, "PeriodLength", NumericRange, nothing),
       unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
       unpack_struct!(data, "AgeAtEnd", NumericRange, nothing),
       unpack_struct!(data, "UserDefinedPeriod", Period,  nothing))
end

struct ProcedureOccurrence <: Criteria
    base::BaseCriteria
    procedure_source_concept::Union{Int, Nothing}
    procedure_type::Vector{Concept}
    procedure_type_exclude::Bool
    modifier::Vector{Concept}
    quantity::Union{NumericRange, Nothing}

    ProcedureOccurrence(data::Dict) = new(
       BaseCriteria(data),
       unpack_scalar!(data, "ProcedureSourceConcept", Int, nothing),
       unpack_vector!(data, "ProcedureType", Concept),
       unpack_scalar!(data, "ProcedureTypeExclude", Bool, false),
       unpack_vector!(data, "Modifier", Concept),
       unpack_struct!(data, "Quantity", NumericRange, nothing))
end

struct VisitOccurrence <: Criteria
    base::BaseCriteria
    place_of_service::Vector{Concept}
    place_of_service_location::Union{Int, Nothing}
    visit_source_concept::Union{Int, Nothing}
    visit_length::Union{NumericRange, Nothing}
    visit_type_exclude::Bool

    VisitOccurrence(data::Dict) = new(
       BaseCriteria(data),
       unpack_vector!(data, "PlaceOfService", Concept),
       unpack_scalar!(data, "PlaceOfServiceLocation", Int, nothing),
       unpack_scalar!(data, "VisitSourceConcept", Int, nothing),
       unpack_struct!(data, "VisitLength", NumericRange, nothing),
       unpack_scalar!(data, "VisitTypeExclude", Bool, false))
end

function Criteria(data::Dict)
    for type in (ConditionOccurrence, DrugExposure, Measurement,
                 Observation, ObservationPeriod, ProcedureOccurrence,
                 VisitOccurrence)
        key = string(nameof(type))
        if haskey(data, key)
            subdata = data[key]
            retval = type(subdata)
            if isempty(subdata)
                delete!(data, key)
            end
            return retval
        end
    end
    return UnknownCriteria(data)
end

struct CohortExpression
    additional_criteria::Union{CriteriaGroup, Nothing}
    censor_window::Period
    censoring_criteria::Vector{Criteria}
    collapse_settings::CollapseSettings
    concept_sets::Vector{ConceptSet}
    end_strategy::Union{EndStrategy, Nothing}
    expression_limit::ResultLimit
    inclusion_rules::Vector{InclusionRule}
    primary_criteria::PrimaryCriteria
    qualified_limit::ResultLimit
    title::Union{String, Nothing}
    version_range::Union{String, Nothing}

    CohortExpression(data::Dict) = new(
      unpack_struct!(data, "AdditionalCriteria", CriteriaGroup, nothing),
      unpack_struct!(data, "CensorWindow", Period),
      unpack_vector!(data, "CensoringCriteria", Criteria),
      unpack_struct!(data, "CollapseSettings", CollapseSettings),
      unpack_vector!(data, "ConceptSets", ConceptSet),
      unpack_struct!(data, "EndStrategy", EndStrategy, nothing),
      unpack_struct!(data, "ExpressionLimit", ResultLimit),
      unpack_vector!(data, "InclusionRules", InclusionRule),
      unpack_struct!(data, "PrimaryCriteria", PrimaryCriteria),
      unpack_struct!(data, "QualifiedLimit", ResultLimit),
      unpack_string!(data, "Title", nothing),
      unpack_string!(data, "cdmVersionRange", nothing)
    )

end

end
