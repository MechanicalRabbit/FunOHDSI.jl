module Circe

using Dates
using PrettyPrinting

import Base: isempty, parse

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
    retval = unpack!(type, bucket)
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
        push!(retval, unpack!(type, item))
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

@Base.kwdef struct DateRange
    value::Date
    op::String
    extent::Union{Date, Nothing} = nothing
end

unpack!(::Type{DateRange}, data::Dict) = DateRange(
    value = unpack_scalar!(data, "Value", Date),
    op = unpack_string!(data, "Op"),
    extent = unpack_scalar!(data, "Extent", Date, nothing))

function PrettyPrinting.quoteof(obj::DateRange)
    ex = Expr(:call, nameof(DateRange))
    push!(ex.args, Expr(:kw, :value, obj.value))
    push!(ex.args, Expr(:kw, :op, obj.op))
    obj.extent === nothing || push!(ex.args, Expr(:kw, :extent, obj.extent))
    ex
end

@Base.kwdef struct TextFilter
    text::String
    op::String
end

unpack!(::Type{TextFilter}, data::Dict) = TextFilter(
    text = unpack_string!(data, "Text"),
    op = unpack_string!(data, "Op"))

function PrettyPrinting.quoteof(obj::TextFilter)
    ex = Expr(:call, nameof(TextFilter))
    push!(ex.args, Expr(:kw, :text, obj.text))
    push!(ex.args, Expr(:kw, :op, obj.op))
    ex
end

@Base.kwdef struct NumericRange
    value::Number
    op::String
    extent::Union{Number, Nothing} = nothing
end

unpack!(::Type{NumericRange}, data::Dict) = NumericRange(
    value = unpack_scalar!(data, "Value", Number),
    op = unpack_string!(data, "Op"),
    extent = unpack_scalar!(data, "Extent", Number, nothing))

function PrettyPrinting.quoteof(obj::NumericRange)
    ex = Expr(:call, nameof(NumericRange))
    push!(ex.args, Expr(:kw, :value, obj.value))
    push!(ex.args, Expr(:kw, :op, obj.op))
    obj.extent === nothing || push!(ex.args, Expr(:kw, :extent, obj.extent))
    ex
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

@Base.kwdef struct Concept
    concept_class_id::String = ""
    concept_code::String
    concept_id::Int
    concept_name::String
    domain_id::String
    invalid_reason::InvalidReasonFlag
    invalid_reason_caption::String
    standard_concept::StandardConceptFlag
    standard_concept_caption::String
    vocabulary_id::String
end

function unpack!(::Type{Concept}, data::Dict)
    Concept(
        concept_class_id = unpack_string!(data, "CONCEPT_CLASS_ID", ""),
        concept_code = unpack_string!(data, "CONCEPT_CODE"),
        concept_id = unpack_scalar!(data, "CONCEPT_ID", Int),
        concept_name = unpack_string!(data, "CONCEPT_NAME"),
        domain_id = unpack_string!(data, "DOMAIN_ID"),
        invalid_reason = unpack_scalar!(data, "INVALID_REASON", InvalidReasonFlag),
        invalid_reason_caption = unpack_string!(data, "INVALID_REASON_CAPTION"),
        standard_concept = unpack_scalar!(data, "STANDARD_CONCEPT", StandardConceptFlag),
        standard_concept_caption = unpack_string!(data, "STANDARD_CONCEPT_CAPTION"),
        vocabulary_id = unpack_string!(data, "VOCABULARY_ID"))
end

function PrettyPrinting.quoteof(obj::Concept)
    ex = Expr(:call, nameof(Concept))
    push!(ex.args, Expr(:kw, :concept_class_id, obj.concept_class_id))
    push!(ex.args, Expr(:kw, :concept_code, obj.concept_code))
    push!(ex.args, Expr(:kw, :concept_id, obj.concept_id))
    push!(ex.args, Expr(:kw, :concept_name, obj.concept_name))
    push!(ex.args, Expr(:kw, :domain_id, obj.domain_id))
    push!(ex.args, Expr(:kw, :invalid_reason, obj.invalid_reason))
    push!(ex.args, Expr(:kw, :invalid_reason_caption, obj.invalid_reason_caption))
    push!(ex.args, Expr(:kw, :standard_concept, obj.standard_concept))
    push!(ex.args, Expr(:kw, :standard_concept_caption, obj.standard_concept_caption))
    push!(ex.args, Expr(:kw, :vocabulary_id, obj.vocabulary_id))
    ex
end

abstract type Expression end

abstract type Criteria <: Expression end

function Base.getproperty(obj::Criteria, prop::Symbol)
    if prop in fieldnames(BaseCriteria)
        return getfield(obj.base, prop)
    else
        return getfield(obj, prop)
    end
end

@Base.kwdef struct Endpoint
    days::Union{Int, Nothing} = nothing
    coeff::Union{Int, Nothing} = nothing
end

unpack!(::Type{Endpoint}, data::Dict) = Endpoint(
    days = unpack_scalar!(data, "Days", Int, nothing),
    coeff = unpack_scalar!(data, "Coeff", Int, nothing))

function PrettyPrinting.quoteof(obj::Endpoint)
    ex = Expr(:call, nameof(Endpoint))
    obj.days === nothing || push!(ex.args, Expr(:kw, :days, obj.days))
    obj.coeff === nothing || push!(ex.args, Expr(:kw, :coeff, obj.coeff))
    ex
end

@Base.kwdef struct Window
    start::Endpoint
    end_::Endpoint
    use_index_end::Union{Bool, Nothing} = nothing
    use_event_end::Union{Bool, Nothing} = nothing
end

unpack!(::Type{Window}, data::Dict) = Window(
    start = unpack_struct!(data, "Start", Endpoint),
    end_ = unpack_struct!(data, "End", Endpoint),
    use_index_end = unpack_scalar!(data, "UseIndexEnd", Bool, nothing),
    use_event_end = unpack_scalar!(data, "UseEventEnd", Bool, nothing))

function PrettyPrinting.quoteof(obj::Window)
    ex = Expr(:call, nameof(Window))
    push!(ex.args, Expr(:kw, :start, obj.start))
    push!(ex.args, Expr(:kw, :end_, obj.end_))
    obj.use_index_end === nothing || push!(ex.args, Expr(:kw, :use_index_end, obj.use_index_end))
    obj.use_event_end === nothing || push!(ex.args, Expr(:kw, :use_event_end, obj.use_event_end))
    ex
end

@enum OccurrenceType EXACTLY=0 AT_MOST=1 AT_LEAST=2
Base.parse(::Type{OccurrenceType}, s::String) =
    s == "0" ? EXACTLY :
         "1" ? AT_MOST :
         "2" ? AT_LEAST :
         throw(DomainError(s, "Unknown Occurrence Type"))

@Base.kwdef struct Occurrence
    type::OccurrenceType
    count::Int
    is_distinct::Bool = false
    count_column::Union{String, Nothing} = nothing
end

unpack!(::Type{Occurrence}, data::Dict) = Occurrence(
    type = unpack_scalar!(data, "Type", OccurrenceType),
    count = unpack_scalar!(data, "Count", Int),
    is_distinct = unpack_scalar!(data, "IsDistinct", Bool, false),
    count_column = unpack_string!(data, "CountColumn", nothing))

function PrettyPrinting.quoteof(obj::Occurrence)
    ex = Expr(:call, nameof(Occurrence))
    push!(ex.args, Expr(:kw, :type, obj.type))
    push!(ex.args, Expr(:kw, :count, obj.count))
    obj.is_distinct == false || push!(ex.args, Expr(:kw, :is_distinct, obj.is_distinct))
    obj.count_column === nothing || push!(ex.args, Expr(:kw, :count_column, obj.count_column))
    ex
end

@Base.kwdef struct CorrelatedCriteria
    criteria::Union{Criteria, Nothing} = nothing
    end_window::Union{Window, Nothing} = nothing
    ignore_observation_period::Bool = false
    occurrence::Union{Occurrence, Nothing} = nothing
    restrict_visit::Bool = false
    start_window::Union{Window, Nothing} = nothing
end

unpack!(::Type{CorrelatedCriteria}, data::Dict) = CorrelatedCriteria(
    criteria = unpack_struct!(data, "Criteria", Criteria, nothing),
    end_window = unpack_struct!(data, "EndWindow", Window, nothing),
    ignore_observation_period = unpack_scalar!(data, "IgnoreObservationPeriod", Bool, false),
    occurrence = unpack_struct!(data, "Occurrence", Occurrence, nothing),
    restrict_visit = unpack_scalar!(data, "RestrictVisit", Bool, false),
    start_window = unpack_struct!(data, "StartWindow", Window, nothing))

function PrettyPrinting.quoteof(obj::CorrelatedCriteria)
    ex = Expr(:call, nameof(CorrelatedCriteria))
    obj.criteria === nothing || push!(ex.args, Expr(:kw, :criteria, obj.criteria))
    obj.end_window === nothing || push!(ex.args, Expr(:kw, :end_window, obj.end_window))
    obj.ignore_observation_period == false || push!(ex.args, Expr(:kw, :ignore_observation_period, obj.ignore_observation_period))
    obj.occurrence == nothing || push!(ex.args, Expr(:kw, :occurrence, obj.occurrence))
    obj.restrict_visit == false || push!(ex.args, Expr(:kw, :restrict_visit, obj.restrict_visit))
    obj.start_window === nothing || push!(ex.args, Expr(:kw, :start_window, obj.start_window))
    ex
end

@Base.kwdef struct DemographicCriteria
    age::Union{NumericRange, Nothing} = nothing
    ethnicity::Vector{Concept} = Concept[]
    gender::Vector{Concept} = Concept[]
    occurrence_end_date::Union{DateRange, Nothing} = nothing
    occurrence_start_date::Union{DateRange, Nothing} = nothing
    race::Vector{Concept} = Concept[]
end

unpack!(::Type{DemographicCriteria}, data::Dict) = DemographicCriteria(
    age = unpack_struct!(data, "Age", NumericRange, nothing),
    ethnicity = unpack_vector!(data, "Ethnicity", Concept),
    gender = unpack_vector!(data, "Gender", Concept),
    occurrence_end_date = unpack_struct!(data, "OccurrenceEndDate", DateRange, nothing),
    occurrence_start_date = unpack_struct!(data, "OccurrenceStartDate", DateRange, nothing),
    race = unpack_vector!(data, "Race", Concept))

function PrettyPrinting.quoteof(obj::DemographicCriteria)
    ex = Expr(:call, nameof(DemographicCriteria))
    obj.age === nothing || push!(ex.args, Expr(:kw, :age, obj.age))
    isempty(obj.ethnicity) || push!(ex.args, Expr(:kw, :ethnicity, obj.ethnicity))
    isempty(obj.gender) || push!(ex.args, Expr(:kw, :gender, obj.gender))
    obj.occurrence_end_date === nothing || push!(ex.args, Expr(:kw, :occurrence_end_date, obj.occurrence_end_date))
    obj.occurrence_start_date === nothing || push!(ex.args, Expr(:kw, :occurrence_start_date, obj.occurrence_start_date))
    isempty(obj.race) || push!(ex.args, Expr(:kw, :race, obj.race))
    ex
end

@Base.kwdef struct CriteriaGroup
    count::Union{Int, Nothing} = nothing
    correlated_criteria::Vector{CorrelatedCriteria} = CorrelatedCriteria[]
    demographic_criteria::Vector{DemographicCriteria} = DemographicCriteria[]
    groups::Vector{CriteriaGroup} = CriteriaGroup[]
    type::Union{String, Nothing} = nothing

end

unpack!(::Type{CriteriaGroup}, data::Dict) = CriteriaGroup(
    count = unpack_scalar!(data, "Count", Int, nothing),
    correlated_criteria = unpack_vector!(data, "CriteriaList", CorrelatedCriteria),
    demographic_criteria = unpack_vector!(data, "DemographicCriteriaList", DemographicCriteria),
    groups = unpack_vector!(data, "Groups", CriteriaGroup),
    type = unpack_string!(data, "Type", nothing))

function PrettyPrinting.quoteof(obj::CriteriaGroup)
    ex = Expr(:call, nameof(CriteriaGroup))
    obj.count === nothing || push!(ex.args, Expr(:kw, :count, obj.count))
    isempty(obj.correlated_criteria) || push!(ex.args, Expr(:kw, :correlated_criteria, obj.correlated_criteria))
    isempty(obj.demographic_criteria) || push!(ex.args, Expr(:kw, :demographic_criteria, obj.demographic_criteria))
    isempty(obj.groups) || push!(ex.args, Expr(:kw, :groups, obj.groups))
    obj.type === nothing || push!(ex.args, Expr(:kw, :type, obj.type))
    ex
end

isempty(g::CriteriaGroup) =
    isempty(d.correlated_criteria) &&
    isempty(d.demographic_criteria) &&
    isempty(d.groups)

@enum CollapseType UNKNOWN_COLLAPSE ERA
CollapseType(::Nothing) = UNKNOWN_COLLAPSE
Base.parse(::Type{CollapseType}, s::Union{String, Nothing}) =
    s == "ERA" ? ERA :
    isnothing(s) ? UNKNOWN_COLLAPSE :
         throw(DomainError(s, "Unknown Collapse Type"))

@Base.kwdef struct CollapseSettings
    collapse_type::CollapseType
    era_pad::Int = 0
end

unpack!(::Type{CollapseSettings}, data::Dict) = CollapseSettings(
    collapse_type = unpack_scalar!(data, "CollapseType", CollapseType),
    era_pad = unpack_scalar!(data, "EraPad", Int, 0))

function PrettyPrinting.quoteof(obj::CollapseSettings)
    ex = Expr(:call, nameof(CollapseSettings))
    push!(ex.args, Expr(:kw, :collapse_type, obj.collapse_type))
    obj.era_pad == 0 || push!(ex.args, Expr(:kw, :era_pad, obj.era_pad))
    ex
end

@Base.kwdef struct Period
    start_date::Union{Date, Nothing} = nothing
    end_date::Union{Date, Nothing} = nothing
end

unpack!(::Type{Period}, data::Dict) = Period(
    start_date = unpack_scalar!(data, "StartDate", Dates.Date, nothing),
    end_date = unpack_scalar!(data, "EndDate", Dates.Date, nothing))

function PrettyPrinting.quoteof(obj::Period)
    ex = Expr(:call, nameof(Period))
    obj.start_date === nothing || push!(ex.args, Expr(:kw, :start_date, obj.start_date))
    obj.end_date === nothing || push!(ex.args, Expr(:kw, :end_date, obj.end_date))
    ex
end

@Base.kwdef struct ConceptSetItem
    concept::Concept
    is_excluded::Bool = false
    include_descendants::Bool = false
    include_mapped::Bool = false
end

unpack!(::Type{ConceptSetItem}, data::Dict) = ConceptSetItem(
    concept = unpack_struct!(data, "concept", Concept),
    is_excluded = unpack_scalar!(data, "isExcluded", Bool, false),
    include_descendants = unpack_scalar!(data, "includeDescendants", Bool, false),
    include_mapped = unpack_scalar!(data, "includeMapped", Bool, false))

function PrettyPrinting.quoteof(obj::ConceptSetItem)
    ex = Expr(:call, nameof(ConceptSetItem))
    push!(ex.args, Expr(:kw, :concept, obj.concept))
    obj.is_excluded == false || push!(ex.args, Expr(:kw, :is_excluded, obj.is_excluded))
    obj.include_descendants == false || push!(ex.args, Expr(:kw, :include_descendants, obj.include_descendants))
    obj.include_mapped == false || push!(ex.args, Expr(:kw, :include_mapped, obj.include_mapped))
    ex
end

@Base.kwdef struct ConceptSet
    id::Int
    name::String
    items::Vector{ConceptSetItem} = ConceptSetItem[]
end

function unpack!(::Type{ConceptSet}, data::Dict)
    items = data["expression"]
    retval = ConceptSet(
        id = unpack_scalar!(data, "id", Int),
        name = unpack_string!(data, "name"),
        items = unpack_vector!(items, "items", ConceptSetItem))
    if isempty(items)
       delete!(data, "expression")
    end
    return retval
end

function PrettyPrinting.quoteof(obj::ConceptSet)
    ex = Expr(:call, nameof(ConceptSet))
    push!(ex.args, Expr(:kw, :id, obj.id))
    push!(ex.args, Expr(:kw, :name, obj.name))
    isempty(obj.items) || push!(ex.args, Expr(:kw, :items, obj.items))
    ex
end

abstract type EndStrategy end

@Base.kwdef struct CustomEraStrategy <: EndStrategy
    drug_codeset_id::Union{Int, Nothing} = nothing
    gap_days::Int = 0
    offset::Int = 0
    days_supply_override::Union{Int, Nothing} = nothing
end

unpack!(::Type{CustomEraStrategy}, data::Dict) = CustomEraStrategy(
    drug_codeset_id = unpack_scalar!(data, "DrugCodesetId", Int, nothing),
    gap_days = unpack_scalar!(data, "GapDays", Int, 0),
    offset = unpack_scalar!(data, "Offset", Int, 0),
    days_supply_override = unpack_scalar!(data, "DaysSupplyOverride", Int, nothing))

function PrettyPrinting.quoteof(obj::CustomEraStrategy)
    ex = Expr(:call, nameof(CustomEraStrategy))
    obj.drug_codeset_id == nothing || push!(ex.args, Expr(:kw, :drug_codeset_id, obj.drug_codeset_id))
    obj.gap_days == 0 || push!(ex.args, Expr(:kw, :gap_days, obj.gap_days))
    obj.offset == 0 || push!(ex.args, Expr(:kw, :offset, obj.offset))
    obj.days_supply_override == nothing || push!(ex.args, Expr(:kw, :days_supply_override, obj.days_supply_override))
    ex
end

@Base.kwdef struct DateOffsetStrategy <: EndStrategy
    offset::Integer
    date_field::String
end

unpack!(::Type{DateOffsetStrategy}, data::Dict) = DateOffsetStrategy(
    offset = unpack_scalar!(data, "Offset", Int),
    date_field = unpack_string!(data, "DateField"))

function PrettyPrinting.quoteof(obj::DateOffsetStrategy)
    ex = Expr(:call, nameof(DateOffsetStrategy))
    push!(ex.args, Expr(:kw, :offset, obj.offset))
    push!(ex.args, Expr(:kw, :date_field, obj.date_field))
    ex
end

function unpack!(::Type{EndStrategy}, data::Dict)
    if haskey(data, "DateOffset")
        (key, type) = ("DateOffset", DateOffsetStrategy)
    else
        (key, type) = ("CustomEra", CustomEraStrategy)
    end
    subdata = data[key]
    retval = unpack!(type, subdata)
    if isempty(subdata)
        delete!(data, key)
    end
    return retval
end

@Base.kwdef struct InclusionRule
    name::String
    description::String = ""
    expression::CriteriaGroup
end

unpack!(::Type{InclusionRule}, data::Dict) = InclusionRule(
    name = unpack_string!(data, "name"),
    description = unpack_string!(data, "description", ""),
    expression = unpack_struct!(data, "expression", CriteriaGroup))

function PrettyPrinting.quoteof(obj::InclusionRule)
    ex = Expr(:call, nameof(InclusionRule))
    push!(ex.args, Expr(:kw, :name, obj.name))
    isempty(obj.description) || push!(ex.args, Expr(:kw, :description, obj.description))
    push!(ex.args, Expr(:kw, :expression, obj.expression))
    ex
end

@Base.kwdef struct ObservationFilter
    prior_days::Int = 0
    post_days::Int = 0
end

unpack!(::Type{ObservationFilter}, data::Dict) = ObservationFilter(
    prior_days = unpack_scalar!(data, "PriorDays", Int, 0),
    post_days = unpack_scalar!(data, "PostDays", Int, 0))

function PrettyPrinting.quoteof(obj::ObservationFilter)
    ex = Expr(:call, nameof(ObservationFilter))
    obj.prior_days == 0 || push!(ex.args, Expr(:kw, :prior_days, obj.prior_days))
    obj.post_days == 0 || push!(ex.args, Expr(:kw, :post_days, obj.post_days))
    ex
end

@Base.kwdef struct ResultLimit
    type::String = "First"
end

unpack!(::Type{ResultLimit}, data::Dict) = ResultLimit(
      type = unpack_string!(data, "Type", "First"))

function PrettyPrinting.quoteof(obj::ResultLimit)
    ex = Expr(:call, nameof(ResultLimit))
    obj.type == "First" || push!(ex.args, Expr(:kw, :type, obj.type))
    ex
end

@Base.kwdef struct PrimaryCriteria
    criteria_list::Vector{Criteria}
    observation_window::ObservationFilter
    primary_limit::ResultLimit
end

unpack!(::Type{PrimaryCriteria}, data::Dict) = PrimaryCriteria(
    criteria_list = unpack_vector!(data, "CriteriaList", Criteria),
    observation_window = unpack_struct!(data, "ObservationWindow", ObservationFilter),
    primary_limit = unpack_struct!(data, "PrimaryCriteriaLimit", ResultLimit))

function PrettyPrinting.quoteof(obj::PrimaryCriteria)
    ex = Expr(:call, nameof(PrimaryCriteria))
    push!(ex.args, Expr(:kw, :criteria_list, obj.criteria_list))
    push!(ex.args, Expr(:kw, :observation_window, obj.observation_window))
    push!(ex.args, Expr(:kw, :primary_limit, obj.primary_limit))
    ex
end

@Base.kwdef struct BaseCriteria
    age::Union{NumericRange, Nothing} = nothing
    codeset_id::Union{Int, Nothing} = nothing
    correlated_criteria::Union{CriteriaGroup, Nothing} = nothing
    first::Bool = false
    gender::Vector{Concept} = Concept[]
    occurrence_end_date::Union{DateRange, Nothing} = nothing
    occurrence_start_date::Union{DateRange, Nothing} = nothing
    provider_specialty::Vector{Concept} = Concept[]
    visit_type::Vector{Concept} = Concept[]
end

unpack!(::Type{BaseCriteria}, data::Dict) = BaseCriteria(
    age = unpack_struct!(data, "Age", NumericRange, nothing),
    codeset_id = unpack_scalar!(data, "CodesetId", Int, nothing),
    correlated_criteria = unpack_struct!(data, "CorrelatedCriteria", CriteriaGroup, nothing),
    first = unpack_scalar!(data, "First", Bool, false),
    gender = unpack_vector!(data, "Gender", Concept),
    occurrence_end_date = unpack_struct!(data, "OccurrenceEndDate", DateRange, nothing),
    occurrence_start_date = unpack_struct!(data, "OccurrenceStartDate", DateRange, nothing),
    provider_specialty = unpack_vector!(data, "ProviderSpecialty", Concept),
    visit_type = unpack_vector!(data, "VisitType", Concept))

function PrettyPrinting.quoteof(obj::BaseCriteria)
    ex = Expr(:call, nameof(BaseCriteria))
    obj.age === nothing || push!(ex.args, Expr(:kw, :age, obj.age))
    obj.codeset_id === nothing || push!(ex.args, Expr(:kw, :codeset_id, obj.codeset_id))
    obj.correlated_criteria === nothing || push!(ex.args, Expr(:kw, :correlated_criteria, obj.correlated_criteria))
    obj.first === false || push!(ex.args, Expr(:kw, :first, obj.first))
    isempty(obj.gender) || push!(ex.args, Expr(:kw, :gender, obj.gender))
    obj.occurrence_end_date === nothing || push!(ex.args, Expr(:kw, :occurrence_end_date, obj.occurrence_end_date))
    obj.occurrence_start_date === nothing || push!(ex.args, Expr(:kw, :occurrence_start_date, obj.occurrence_start_date))
    isempty(obj.provider_specialty) || push!(ex.args, Expr(:kw, :provider_specialty, obj.provider_specialty))
    isempty(obj.visit_type) || push!(ex.args, Expr(:kw, :visit_type, obj.visit_type))
    ex
end

struct UnknownCriteria <: Criteria
end

unpack!(::Type{UnknownCriteria}, data::Dict) = UnknownCriteria()

PrettyPrinting.quoteof(obj::UnknownCriteria) =
    Expr(:call, nameof(UnknownCriteria))

@Base.kwdef struct ConditionEra <: Criteria
    # like DrugEra, but missing gap_length?
    base::BaseCriteria
    era_end_date::Union{DateRange, Nothing} = nothing
    era_start_date::Union{DateRange, Nothing} = nothing
    era_length::Union{NumericRange, Nothing} = nothing
    occurrence_count::Union{NumericRange, Nothing} = nothing
    age_at_start::Union{NumericRange, Nothing} = nothing
    age_at_end::Union{NumericRange, Nothing} = nothing
end

unpack!(::Type{ConditionEra}, data::Dict) = ConditionEra(
    base = unpack!(BaseCriteria, data),
    era_end_date = unpack_struct!(data, "EraEndDate", DateRange, nothing),
    era_start_date = unpack_struct!(data, "EraStartDate", DateRange, nothing),
    era_length = unpack_struct!(data, "EraLength", NumericRange, nothing),
    occurrence_count = unpack_struct!(data, "OccurrenceCount", NumericRange, nothing),
    age_at_start = unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
    age_at_end = unpack_struct!(data, "AgeAtEnd", NumericRange, nothing))

function PrettyPrinting.quoteof(obj::ConditionEra)
    ex = Expr(:call, nameof(ConditionEra))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.era_end_date === nothing || push!(ex.args, Expr(:kw, :era_end_date, obj.era_end_date))
    obj.era_start_date === nothing || push!(ex.args, Expr(:kw, :era_start_date, obj.era_start_date))
    obj.era_length === nothing || push!(ex.args, Expr(:kw, :era_length, obj.era_length))
    obj.occurrence_count === nothing || push!(ex.args, Expr(:kw, :occurrence_count, obj.occurrence_count))
    obj.age_at_start === nothing || push!(ex.args, Expr(:kw, :age_at_start, obj.age_at_start))
    obj.age_at_end === nothing || push!(ex.args, Expr(:kw, :age_at_end, obj.age_at_end))
    ex
end

@Base.kwdef struct ConditionOccurrence <: Criteria
    base::BaseCriteria
    condition_source_concept::Union{Int, Nothing} = nothing
    condition_status::Vector{Concept} = Concept[]
    condition_type::Vector{Concept} = Concept[]
    condition_type_exclude::Bool = false
    stop_reason::Union{TextFilter, Nothing} = nothing
end

unpack!(::Type{ConditionOccurrence}, data::Dict) = ConditionOccurrence(
    base = unpack!(BaseCriteria, data),
    condition_source_concept = unpack_scalar!(data, "ConditionSourceConcept", Int, nothing),
    condition_status = unpack_vector!(data, "ConditionStatus", Concept),
    condition_type = unpack_vector!(data, "ConditionType", Concept),
    condition_type_exclude = unpack_scalar!(data, "ConditionTypeExclude", Bool, false),
    stop_reason = unpack_struct!(data, "StopReason", TextFilter, nothing))

function PrettyPrinting.quoteof(obj::ConditionOccurrence)
    ex = Expr(:call, nameof(ConditionOccurrence))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.condition_source_concept === nothing || push!(ex.args, Expr(:kw, :condition_source_concept, obj.condition_source_concept))
    isempty(obj.condition_status) || push!(ex.args, Expr(:kw, :condition_status, obj.condition_status))
    isempty(obj.condition_type) || push!(ex.args, Expr(:kw, :condition_type, obj.condition_type))
    obj.condition_type_exclude == false || push!(ex.args, Expr(:kw, :condition_type_exclude, obj.condition_type_exclude))
    obj.stop_reason === nothing || push!(ex.args, Expr(:kw, :stop_reason, obj.stop_reason))
    ex
end

@Base.kwdef struct Death <: Criteria
    base::BaseCriteria
    death_source_concept::Union{Int, Nothing} = nothing
    death_type::Vector{Concept} = Concept[]
    death_type_exclude::Bool = false
end

unpack!(::Type{Death}, data::Dict) = Death(
    base = unpack!(BaseCriteria, data),
    death_source_concept = unpack_scalar!(data, "DeathSourceConcept", Int, nothing),
    death_type = unpack_vector!(data, "DeathType", Concept),
    death_type_exclude = unpack_scalar!(data, "DeathTypeExclude", Bool, false))

function PrettyPrinting.quoteof(obj::Death)
    ex = Expr(:call, nameof(Death))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.death_source_concept === nothing || push!(ex.args, Expr(:kw, :death_source_concept, obj.death_source_concept))
    isempty(obj.death_type) || push!(ex.args, Expr(:kw, :death_type, obj.death_type))
    obj.death_type_exclude == false || push!(ex.args, Expr(:kw, :death_type_exclude, obj.death_type_exclude))
    ex
end

@Base.kwdef struct DeviceExposure <: Criteria
    base::BaseCriteria
    device_source_concept::Union{Int, Nothing} = nothing
    device_type::Vector{Concept} = Concept[]
    device_type_exclude::Bool = false
    quantity::Union{NumericRange, Nothing} = nothing
    unique_device_id::Union{TextFilter, Nothing} = nothing
end

unpack!(::Type{DeviceExposure}, data::Dict) = DeviceExposure(
    base = unpack!(BaseCriteria, data),
    device_source_concept = unpack_scalar!(data, "DeviceSourceConcept", Int, nothing),
    device_type = unpack_vector!(data, "DeviceType", Concept),
    device_type_exclude = unpack_scalar!(data, "DeviceTypeExclude", Bool, false),
    quantity = unpack_struct!(data, "Quantity", NumericRange, nothing),
    unique_device_id = unpack_struct!(data, "UniqueDeviceId", TextFilter, nothing))

function PrettyPrinting.quoteof(obj::DeviceExposure)
    ex = Expr(:call, nameof(DeviceExposure))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.device_source_concept === nothing || push!(ex.args, Expr(:kw, :device_source_concept, obj.device_source_concept))
    isempty(obj.device_type) || push!(ex.args, Expr(:kw, :device_type, obj.device_type))
    obj.device_type_exclude == false || push!(ex.args, Expr(:kw, :device_type_exclude, obj.device_type_exclude))
    obj.quantity === nothing || push!(ex.args, Expr(:kw, :quantity, obj.quantity))
    obj.unique_device_id === nothing || push!(ex.args, Expr(:kw, :unique_device_id, obj.unique_device_id))
    ex
end

@Base.kwdef struct DrugEra <: Criteria
    base::BaseCriteria
    era_end_date::Union{DateRange, Nothing} = nothing
    era_start_date::Union{DateRange, Nothing} = nothing
    era_length::Union{NumericRange, Nothing} = nothing
    occurrence_count::Union{NumericRange, Nothing} = nothing
    gap_days::Union{NumericRange, Nothing} = nothing
    age_at_start::Union{NumericRange, Nothing} = nothing
    age_at_end::Union{NumericRange, Nothing} = nothing
end

unpack!(::Type{DrugEra}, data::Dict) = DrugEra(
    base = unpack!(BaseCriteria, data),
    era_end_date = unpack_struct!(data, "EraEndDate", DateRange, nothing),
    era_start_date = unpack_struct!(data, "EraStartDate", DateRange, nothing),
    era_length = unpack_struct!(data, "EraLength", NumericRange, nothing),
    occurrence_count = unpack_struct!(data, "OccurrenceCount", NumericRange, nothing),
    gap_days = unpack_struct!(data, "GapDays", NumericRange, nothing),
    age_at_start = unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
    age_at_end = unpack_struct!(data, "AgeAtEnd", NumericRange, nothing))

function PrettyPrinting.quoteof(obj::DrugEra)
    ex = Expr(:call, nameof(DrugEra))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.era_end_date === nothing || push!(ex.args, Expr(:kw, :era_end_date, obj.era_end_date))
    obj.era_start_date === nothing || push!(ex.args, Expr(:kw, :era_start_date, obj.era_start_date))
    obj.era_length === nothing || push!(ex.args, Expr(:kw, :era_length, obj.era_length))
    obj.occurrence_count === nothing || push!(ex.args, Expr(:kw, :occurrence_count, obj.occurrence_count))
    obj.gap_days === nothing || push!(ex.args, Expr(:kw, :gap_days, obj.gap_days))
    obj.age_at_start === nothing || push!(ex.args, Expr(:kw, :age_at_start, obj.age_at_start))
    obj.age_at_end === nothing || push!(ex.args, Expr(:kw, :age_at_end, obj.age_at_end))
    ex
end

@Base.kwdef struct DrugExposure <: Criteria
    base::BaseCriteria
    drug_source_concept::Union{Int, Nothing} = nothing
    drug_type::Vector{Concept} = Concept[]
    drug_type_exclude::Bool = false
    refills::Union{NumericRange, Nothing} = nothing
    quantity::Union{NumericRange, Nothing} = nothing
    days_supply::Union{NumericRange, Nothing} = nothing
    route_concept::Vector{Concept} = Concept[]
    effective_drug_dose::Union{NumericRange, Nothing} = nothing
    dose_unit::Vector{Concept} = Concept[]
    lot_number::Union{TextFilter, Nothing} = nothing
    stop_reason::Union{TextFilter, Nothing} = nothing
end

unpack!(::Type{DrugExposure}, data::Dict) = DrugExposure(
    base = unpack!(BaseCriteria, data),
    drug_source_concept = unpack_scalar!(data, "DrugSourceConcept", Int, nothing),
    drug_type = unpack_vector!(data, "DrugType", Concept),
    drug_type_exclude = unpack_scalar!(data, "DrugTypeExclude", Bool, false),
    refills = unpack_struct!(data, "Refills", NumericRange, nothing),
    quantity = unpack_struct!(data, "Quantity", NumericRange, nothing),
    days_supply = unpack_struct!(data, "DaysSupply", NumericRange, nothing),
    route_concept = unpack_vector!(data, "RouteConcept", Concept),
    effective_drug_dose = unpack_struct!(data, "EffectiveDrugDose", NumericRange, nothing),
    dose_unit = unpack_vector!(data, "DoseUnit", Concept),
    lot_number = unpack_struct!(data, "LotNumber", TextFilter, nothing),
    stop_reason = unpack_struct!(data, "StopReason", TextFilter, nothing))

function PrettyPrinting.quoteof(obj::DrugExposure)
    ex = Expr(:call, nameof(DrugExposure))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.drug_source_concept === nothing || push!(ex.args, Expr(:kw, :drug_source_concept, obj.drug_source_concept))
    isempty(obj.drug_type) || push!(ex.args, Expr(:kw, :drug_type, obj.drug_type))
    obj.drug_type_exclude == false || push!(ex.args, Expr(:kw, :drug_type_exclude, obj.drug_type_exclude))
    obj.refills === nothing || push!(ex.args, Expr(:kw, :refills, obj.refills))
    obj.quantity === nothing || push!(ex.args, Expr(:kw, :quantity, obj.quantity))
    obj.days_supply === nothing || push!(ex.args, Expr(:kw, :days_supply, obj.days_supply))
    isempty(obj.route_concept) || push!(ex.args, Expr(:kw, :route_concept, obj.route_concept))
    obj.effective_drug_dose === nothing || push!(ex.args, Expr(:kw, :effective_drug_dose, obj.effective_drug_dose))
    isempty(obj.dose_unit) || push!(ex.args, Expr(:kw, :dose_unit, obj.dose_unit))
    obj.lot_number === nothing || push!(ex.args, Expr(:kw, :lot_number, obj.lot_number))
    obj.stop_reason === nothing || push!(ex.args, Expr(:kw, :stop_reason, obj.stop_reason))
    ex
end

@Base.kwdef struct DoseEra <: Criteria
    base::BaseCriteria
    dose_value::Union{NumericRange, Nothing} = nothing
    era_end_date::Union{DateRange, Nothing} = nothing
    era_start_date::Union{DateRange, Nothing} = nothing
    era_length::Union{NumericRange, Nothing} = nothing
    age_at_start::Union{NumericRange, Nothing} = nothing
    age_at_end::Union{NumericRange, Nothing} = nothing
    unit::Vector{Concept} = Concept[]
end

unpack!(::Type{DoseEra}, data::Dict) = DoseEra(
    base = unpack!(BaseCriteria, data),
    dose_value = unpack_struct!(data, "DoseValue", NumericRange, nothing),
    era_end_date = unpack_struct!(data, "EraEndDate", DateRange, nothing),
    era_start_date = unpack_struct!(data, "EraStartDate", DateRange, nothing),
    era_length = unpack_struct!(data, "EraLength", NumericRange, nothing),
    age_at_start = unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
    age_at_end = unpack_struct!(data, "AgeAtEnd", NumericRange, nothing),
    unit = unpack_vector!(data, "Unit", Concept))

function PrettyPrinting.quoteof(obj::DoseEra)
    ex = Expr(:call, nameof(DoseEra))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.era_end_date === nothing || push!(ex.args, Expr(:kw, :era_end_date, obj.era_end_date))
    obj.era_start_date === nothing || push!(ex.args, Expr(:kw, :era_start_date, obj.era_start_date))
    obj.era_length === nothing || push!(ex.args, Expr(:kw, :era_length, obj.era_length))
    obj.age_at_start === nothing || push!(ex.args, Expr(:kw, :age_at_start, obj.age_at_start))
    obj.age_at_end === nothing || push!(ex.args, Expr(:kw, :age_at_end, obj.age_at_end))
    isempty(obj.unit) || push!(ex.args, Expr(:kw, :unit, obj.unit))
    ex
end

@Base.kwdef struct LocationRegion
    codeset_id::Union{Int, Nothing} = nothing
    start_date::Union{DateRange, Nothing} = nothing
    end_date::Union{DateRange, Nothing} = nothing
end

unpack!(::Type{LocationRegion}, data::Dict) = LocationRegion(
    codeset_id = unpack_scalar!(data, "CodesetId", Int, nothing),
    start_date = unpack_struct!(data, "StartDate", DateRange, nothing),
    end_date = unpack_struct!(data, "EndDate", DateRange, nothing))

function PrettyPrinting.quoteof(obj::LocationRegion)
    ex = Expr(:call, nameof(DoseEra))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.codeset_id === nothing || push!(ex.args, Expr(:kw, :codeset_id, obj.codeset_id))
    obj.start_date === nothing || push!(ex.args, Expr(:kw, :start_date, obj.start_date))
    obj.end_date === nothing || push!(ex.args, Expr(:kw, :end_date, obj.end_date))
    ex
end

@Base.kwdef struct Measurement <: Criteria
    base::BaseCriteria
    measurement_source_concept::Union{Int, Nothing} = nothing
    measurement_type::Vector{Concept} = Concept[]
    measurement_type_exclude::Bool = false
    abnormal::Union{Bool, Nothing} = nothing
    range_low::Union{NumericRange, Nothing} = nothing
    range_high::Union{NumericRange, Nothing} = nothing
    range_low_ratio::Union{NumericRange, Nothing} = nothing
    range_high_ratio::Union{NumericRange, Nothing} = nothing
    value_as_number::Union{NumericRange, Nothing} = nothing
    value_as_concept::Vector{Concept} = Concept[]
    operator::Vector{Concept} = Concept[]
    unit::Vector{Concept} = Concept[]
end

unpack!(::Type{Measurement}, data::Dict) = Measurement(
    base = unpack!(BaseCriteria, data),
    measurement_source_concept = unpack_scalar!(data, "MeasurementSourceConcept", Int, nothing),
    measurement_type = unpack_vector!(data, "MeasurementType", Concept),
    measurement_type_exclude = unpack_scalar!(data, "MeasurementTypeExclude", Bool, false),
    abnormal = unpack_scalar!(data, "Abnormal", Bool, nothing),
    range_low = unpack_struct!(data, "RangeLow", NumericRange, nothing),
    range_high = unpack_struct!(data, "RangeHigh", NumericRange, nothing),
    range_low_ratio = unpack_struct!(data, "RangeLowRatio", NumericRange, nothing),
    range_high_ratio = unpack_struct!(data, "RangeHighRatio", NumericRange, nothing),
    value_as_number = unpack_struct!(data, "ValueAsNumber", NumericRange, nothing),
    value_as_concept = unpack_vector!(data, "ValueAsConcept", Concept),
    operator = unpack_vector!(data, "Operator", Concept),
    unit = unpack_vector!(data, "Unit", Concept))

function PrettyPrinting.quoteof(obj::Measurement)
    ex = Expr(:call, nameof(Measurement))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.measurement_source_concept === nothing || push!(ex.args, Expr(:kw, :measurement_source_concept, obj.measurement_source_concept))
    isempty(obj.measurement_type) || push!(ex.args, Expr(:kw, :measurement_type, obj.measurement_type))
    obj.measurement_type_exclude == false || push!(ex.args, Expr(:kw, :measurement_type_exclude, obj.measurement_type_exclude))
    obj.abnormal === nothing || push!(ex.args, Expr(:kw, :abnormal, obj.abnormal))
    obj.range_low === nothing || push!(ex.args, Expr(:kw, :range_low, obj.range_low))
    obj.range_high === nothing || push!(ex.args, Expr(:kw, :range_high, obj.range_high))
    obj.range_low_ratio === nothing || push!(ex.args, Expr(:kw, :range_low_ratio, obj.range_low_ratio))
    obj.range_high_ratio === nothing || push!(ex.args, Expr(:kw, :range_high_ratio, obj.range_high_ratio))
    obj.value_as_number === nothing || push!(ex.args, Expr(:kw, :value_as_number, obj.value_as_number))
    isempty(obj.value_as_concept) || push!(ex.args, Expr(:kw, :value_as_concept, obj.value_as_concept))
    isempty(obj.operator) || push!(ex.args, Expr(:kw, :operator, obj.operator))
    isempty(obj.unit) || push!(ex.args, Expr(:kw, :unit, obj.unit))
    ex
end

@Base.kwdef struct Observation <: Criteria
    base::BaseCriteria
    observation_source_concept::Union{Int, Nothing} = nothing
    observation_type::Vector{Concept} = Concept[]
    observation_type_exclude::Bool = false
    value_as_string::Union{TextFilter, Nothing} = nothing
    value_as_number::Union{NumericRange, Nothing} = nothing
    value_as_concept::Vector{Concept} = Concept[]
    qualifier::Vector{Concept} = Concept[]
    unit::Vector{Concept} = Concept[]
end

unpack!(::Type{Observation}, data::Dict) = Observation(
    base = unpack!(BaseCriteria, data),
    observation_source_concept = unpack_scalar!(data, "ObservationSourceConcept", Int, nothing),
    observation_type = unpack_vector!(data, "ObservationType", Concept),
    observation_type_exclude = unpack_scalar!(data, "ObservationTypeExclude", Bool, false),
    value_as_string = unpack_struct!(data, "ValueAsString", TextFilter, nothing),
    value_as_number = unpack_struct!(data, "ValueAsNumber", NumericRange, nothing),
    value_as_concept = unpack_vector!(data, "ValueAsConcept", Concept),
    qualifier = unpack_vector!(data, "Qualifier", Concept),
    unit = unpack_vector!(data, "Unit", Concept))

function PrettyPrinting.quoteof(obj::Observation)
    ex = Expr(:call, nameof(Observation))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.observation_source_concept === nothing || push!(ex.args, Expr(:kw, :observation_source_concept, obj.observation_source_concept))
    isempty(obj.observation_type) || push!(ex.args, Expr(:kw, :observation_type, obj.observation_type))
    obj.observation_type_exclude == false || push!(ex.args, Expr(:kw, :observation_type_exclude, obj.observation_type_exclude))
    obj.value_as_string === nothing || push!(ex.args, Expr(:kw, :value_as_string, obj.value_as_string))
    obj.value_as_number === nothing || push!(ex.args, Expr(:kw, :value_as_number, obj.value_as_number))
    isempty(obj.value_as_concept) || push!(ex.args, Expr(:kw, :value_as_concept, obj.value_as_concept))
    isempty(obj.qualifier) || push!(ex.args, Expr(:kw, :qualifier, obj.qualifiter))
    isempty(obj.unit) || push!(ex.args, Expr(:kw, :unit, obj.unit))
    ex
end

@Base.kwdef struct ObservationPeriod <: Criteria
    base::BaseCriteria
    period_type::Vector{Concept} = Concept[]
    period_type_exclude::Bool = false
    period_start_date::Union{DateRange, Nothing} = nothing
    period_end_date::Union{DateRange, Nothing} = nothing
    period_length::Union{NumericRange, Nothing} = nothing
    age_at_start::Union{NumericRange, Nothing} = nothing
    age_at_end::Union{NumericRange, Nothing} = nothing
    user_defined_period::Union{Period, Nothing} = nothing
end

unpack!(::Type{ObservationPeriod}, data::Dict) = ObservationPeriod(
    base = unpack!(BaseCriteria, data),
    period_type = unpack_vector!(data, "PeriodType", Concept),
    period_type_exclude = unpack_scalar!(data, "PeriodTypeExclude", Bool, false),
    period_start_date = unpack_struct!(data, "PeriodStartDate", DateRange, nothing),
    period_end_date = unpack_struct!(data, "PeriodEndDate", DateRange, nothing),
    period_length = unpack_struct!(data, "PeriodLength", NumericRange, nothing),
    age_at_start = unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
    age_at_end = unpack_struct!(data, "AgeAtEnd", NumericRange, nothing),
    user_defined_period = unpack_struct!(data, "UserDefinedPeriod", Period,  nothing))

function PrettyPrinting.quoteof(obj::ObservationPeriod)
    ex = Expr(:call, nameof(ObservationPeriod))
    push!(ex.args, Expr(:kw, :base, obj.base))
    isempty(obj.period_type) || push!(ex.args, Expr(:kw, :period_type, obj.period_type))
    obj.period_type_exclude == false || push!(ex.args, Expr(:kw, :period_type_exclude, obj.period_type_exclude))
    obj.period_start_date === nothing || push!(ex.args, Expr(:kw, :period_start_date, obj.period_start_date))
    obj.period_end_date === nothing || push!(ex.args, Expr(:kw, :period_end_date, obj.period_end_date))
    obj.period_length === nothing || push!(ex.args, Expr(:kw, :period_length, obj.period_length))
    obj.age_at_start === nothing || push!(ex.args, Expr(:kw, :age_at_start, obj.age_at_start))
    obj.age_at_end === nothing || push!(ex.args, Expr(:kw, :age_at_end, obj.age_at_end))
    obj.user_defined_period === nothing || push!(ex.args, Expr(:kw, :user_defined_period, obj.user_defined_period))
    ex
end

@Base.kwdef struct PayerPlanPeriod <: Criteria
    base::BaseCriteria
    period_type::Vector{Concept} = Concept
    period_type_exclude::Bool = false
    period_start_date::Union{DateRange, Nothing} = nothing
    period_end_date::Union{DateRange, Nothing} = nothing
    period_length::Union{NumericRange, Nothing} = nothing
    age_at_start::Union{NumericRange, Nothing} = nothing
    age_at_end::Union{NumericRange, Nothing} = nothing
    payer_concept::Union{Int, Nothing} = nothing
    plan_concept::Union{Int, Nothing} = nothing
    sponsor_concept::Union{Int, Nothing} = nothing
    stop_reason_concept::Union{Int, Nothing} = nothing
    stop_reason_source_concept::Union{Int, Nothing} = nothing
    payer_source_concept::Union{Int, Nothing} = nothing
    plan_source_concept::Union{Int, Nothing} = nothing
    sponsor_source_concept::Union{Int, Nothing} = nothing
    user_defined_period::Union{Period, Nothing} = nothing
end

unpack!(::Type{PayerPlanPeriod}, data::Dict) = PayerPlanPeriod(
    base = unpack!(BaseCriteria, data),
    period_type = unpack_vector!(data, "PeriodType", Concept),
    period_type_exclude = unpack_scalar!(data, "PeriodTypeExclude", Bool, false),
    period_start_date = unpack_struct!(data, "PeriodStartDate", DateRange, nothing),
    period_end_date = unpack_struct!(data, "PeriodEndDate", DateRange, nothing),
    period_length = unpack_struct!(data, "PeriodLength", NumericRange, nothing),
    age_at_start = unpack_struct!(data, "AgeAtStart", NumericRange, nothing),
    age_at_end = unpack_struct!(data, "AgeAtEnd", NumericRange, nothing),
    payer_concept = unpack_scalar!(data, "PayerConcept", Int, nothing),
    plan_concept = unpack_scalar!(data, "PlanConcept", Int, nothing),
    sponsor_concept = unpack_scalar!(data, "SponsorConcept", Int, nothing),
    stop_reason_concept = unpack_scalar!(data, "StopReasonConcept", Int, nothing),
    stop_reason_source_concept = unpack_scalar!(data, "StopReasonSourceConcept", Int, nothing),
    payer_source_concept = unpack_scalar!(data, "PayerSourceConcept", Int, nothing),
    plan_source_concept = unpack_scalar!(data, "PlanSourceConcept", Int, nothing),
    sponsor_source_concept = unpack_scalar!(data, "SponsorSourceConcept", Int, nothing),
    user_defined_period = unpack_struct!(data, "UserDefinedPeriod", Period,  nothing))

function PrettyPrinting.quoteof(obj::PayerPlanPeriod)
    ex = Expr(:call, nameof(PayerPlanPeriod))
    push!(ex.args, Expr(:kw, :base, obj.base))
    isempty(obj.period_type) || push!(ex.args, Expr(:kw, :period_type, obj.period_type))
    obj.period_type_exclude == false || push!(ex.args, Expr(:kw, :period_type_exclude, obj.period_type_exclude))
    obj.period_start_date === nothing || push!(ex.args, Expr(:kw, :period_start_date, obj.period_start_date))
    obj.period_end_date === nothing || push!(ex.args, Expr(:kw, :period_end_date, obj.period_end_date))
    obj.period_length === nothing || push!(ex.args, Expr(:kw, :period_length, obj.period_length))
    obj.age_at_start === nothing || push!(ex.args, Expr(:kw, :age_at_start, obj.age_at_start))
    obj.age_at_end === nothing || push!(ex.args, Expr(:kw, :age_at_end, obj.age_at_end))
    obj.payer_concept === nothing || push!(ex.args, Expr(:kw, :payer_concept, obj.payer_concept))
    obj.plan_concept === nothing || push!(ex.args, Expr(:kw, :plan_concept, obj.plan_concept))
    obj.sponsor_concept === nothing || push!(ex.args, Expr(:kw, :sponsor_concept, obj.sponsor_concept))
    obj.stop_reason_concept === nothing || push!(ex.args, Expr(:kw, :stop_reason_concept, obj.stop_reason_concept))
    obj.stop_reason_source_concept === nothing || push!(ex.args, Expr(:kw, :stop_reason_source_concept, obj.stop_reason_source_concept))
    obj.payer_source_concept === nothing || push!(ex.args, Expr(:kw, :payer_source_concept, obj.payer_source_concept))
    obj.plan_source_concept === nothing || push!(ex.args, Expr(:kw, :plan_source_concept, obj.plan_source_concept))
    obj.sponsor_source_concept === nothing || push!(ex.args, Expr(:kw, :sponsor_source_concept, obj.sponsor_source_concept))
    obj.user_defined_period === nothing || push!(ex.args, Expr(:kw, :user_defined_period, obj.user_defined_period))
    ex
end

@Base.kwdef struct ProcedureOccurrence <: Criteria
    base::BaseCriteria
    procedure_source_concept::Union{Int, Nothing} = nothing
    procedure_type::Vector{Concept} = Concept[]
    procedure_type_exclude::Bool = false
    modifier::Vector{Concept} = Concept[]
    quantity::Union{NumericRange, Nothing} = nothing
end

unpack!(::Type{ProcedureOccurrence}, data::Dict) = ProcedureOccurrence(
    base = unpack!(BaseCriteria, data),
    procedure_source_concept = unpack_scalar!(data, "ProcedureSourceConcept", Int, nothing),
    procedure_type = unpack_vector!(data, "ProcedureType", Concept),
    procedure_type_exclude = unpack_scalar!(data, "ProcedureTypeExclude", Bool, false),
    modifier = unpack_vector!(data, "Modifier", Concept),
    quantity = unpack_struct!(data, "Quantity", NumericRange, nothing))

function PrettyPrinting.quoteof(obj::ProcedureOccurrence)
    ex = Expr(:call, nameof(ProcedureOccurrence))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.procedure_source_concept === nothing || push!(ex.args, Expr(:kw, :procedure_source_concept, obj.procedure_source_concept))
    isempty(obj.procedure_type) || push!(ex.args, Expr(:kw, :procedure_type, obj.procedure_type))
    obj.procedure_type_exclude == false || push!(ex.args, Expr(:kw, :procedure_type_exclude, obj.procedure_type_exclude))
    isempty(obj.modifier) || push!(ex.args, Expr(:kw, :modifier, obj.modifier))
    obj.quantity === nothing || push!(ex.args, Expr(:kw, :quantity, obj.quantity))
    ex
end

@Base.kwdef struct Specimen <: Criteria
    base::BaseCriteria
    specimen_source_concept::Union{Int, Nothing} = nothing
    specimen_type::Vector{Concept} = Concept[]
    specimen_type_exclude::Bool = false
    quantity::Union{NumericRange, Nothing} = nothing
    unit::Vector{Concept} = Concept[]
    anatomic_site::Vector{Concept} = Concept[]
    disease_status::Vector{Concept} = Concept[]
    source_id::Union{TextFilter, Nothing} = nothing
end

unpack!(::Type{Specimen}, data::Dict) = Specimen(
    base = unpack!(BaseCriteria, data),
    specimen_source_concept = unpack_scalar!(data, "SpecimenSourceConcept", Int, nothing),
    specimen_type = unpack_vector!(data, "SpecimenType", Concept),
    specimen_type_exclude = unpack_scalar!(data, "SpecimenTytpeExclude", Bool, false),
    quantity = unpack_struct!(data, "Quantity", NumericRange, nothing),
    unit = unpack_vector!(data, "Unit", Concept),
    anatomic_site = unpack_vector!(data, "AnatomicSite", Concept),
    disease_status = unpack_vector!(data, "DiseaseStatus", Concept),
    source_id = unpack_scalar!(data, "SourceId", TextFilter, nothing))

function PrettyPrinting.quoteof(obj::Specimen)
    ex = Expr(:call, nameof(Specimen))
    push!(ex.args, Expr(:kw, :base, obj.base))
    obj.speciment_source_concept === nothing || push!(ex.args, Expr(:kw, :speciment_source_concept, obj.speciment_source_concept))
    isempty(obj.speciment_type) || push!(ex.args, Expr(:kw, :speciment_type, obj.speciment_type))
    obj.speciment_type_exclude == false || push!(ex.args, Expr(:kw, :speciment_type_exclude, obj.speciment_type_exclude))
    isempty(obj.quantity) || push!(ex.args, Expr(:kw, :quantity, obj.quantity))
    isempty(obj.unit) || push!(ex.args, Expr(:kw, :unit, obj.unit))
    isempty(obj.anatomic_site) || push!(ex.args, Expr(:kw, :anatomic_site, obj.anatomic_site))
    isempty(obj.disease_status) || push!(ex.args, Expr(:kw, :disease_status, obj.disease_status))
    obj.source_id === nothing || push!(ex.args, Expr(:kw, :source_id, obj.source_id))
    ex
end

@Base.kwdef struct VisitOccurrence <: Criteria
    base::BaseCriteria
    place_of_service::Vector{Concept} = Concept[]
    place_of_service_location::Union{Int, Nothing} = nothing
    visit_source_concept::Union{Int, Nothing} = nothing
    visit_length::Union{NumericRange, Nothing} = nothing
    visit_type_exclude::Bool = false
end

unpack!(::Type{VisitOccurrence}, data::Dict) = VisitOccurrence(
    base = unpack!(BaseCriteria, data),
    place_of_service = unpack_vector!(data, "PlaceOfService", Concept),
    place_of_service_location = unpack_scalar!(data, "PlaceOfServiceLocation", Int, nothing),
    visit_source_concept = unpack_scalar!(data, "VisitSourceConcept", Int, nothing),
    visit_length = unpack_struct!(data, "VisitLength", NumericRange, nothing),
    visit_type_exclude = unpack_scalar!(data, "VisitTypeExclude", Bool, false))

function PrettyPrinting.quoteof(obj::VisitOccurrence)
    ex = Expr(:call, nameof(VisitOccurrence))
    push!(ex.args, Expr(:kw, :base, obj.base))
    isempty(obj.place_of_service) || push!(ex.args, Expr(:kw, :place_of_service, obj.place_of_service))
    obj.place_of_service_location === nothing || push!(ex.args, Expr(:kw, :place_of_service_location, obj.place_of_service_location))
    obj.visit_source_concept === nothing || push!(ex.args, Expr(:kw, :visit_source_concept, obj.visit_source_concept))
    obj.visit_length === nothing || push!(ex.args, Expr(:kw, :visit_length, obj.visit_length))
    obj.visit_type_exclude == false || push!(ex.args, Expr(:kw, :visit_type_exclude, obj.visit_type_exclude))
    ex
end

function unpack!(::Type{Criteria}, data::Dict)
    for type in (ConditionEra, ConditionOccurrence, Death,
                 DeviceExposure, DoseEra, DrugEra, DrugExposure,
                 LocationRegion, Measurement, Observation,
                 ObservationPeriod, PayerPlanPeriod,
                 ProcedureOccurrence, Specimen, VisitOccurrence)
        key = string(nameof(type))
        if haskey(data, key)
            subdata = data[key]
            retval = unpack!(type, subdata)
            if isempty(subdata)
                delete!(data, key)
            end
            return retval
        end
    end
    return unpack!(UnknownCriteria, data)
end

@Base.kwdef struct CohortExpression
    additional_criteria::Union{CriteriaGroup, Nothing} = nothing
    censor_window::Period
    censoring_criteria::Vector{Criteria} = Criteria[]
    collapse_settings::CollapseSettings
    concept_sets::Vector{ConceptSet} = ConceptSet[]
    end_strategy::Union{EndStrategy, Nothing} = nothing
    expression_limit::ResultLimit
    inclusion_rules::Vector{InclusionRule} = InclusionRule[]
    primary_criteria::PrimaryCriteria
    qualified_limit::ResultLimit
    title::Union{String, Nothing} = nothing
    version_range::Union{String, Nothing} = nothing
end

unpack!(::Type{CohortExpression}, data::Dict) = CohortExpression(
    additional_criteria = unpack_struct!(data, "AdditionalCriteria", CriteriaGroup, nothing),
    censor_window = unpack_struct!(data, "CensorWindow", Period),
    censoring_criteria = unpack_vector!(data, "CensoringCriteria", Criteria),
    collapse_settings = unpack_struct!(data, "CollapseSettings", CollapseSettings),
    concept_sets = unpack_vector!(data, "ConceptSets", ConceptSet),
    end_strategy = unpack_struct!(data, "EndStrategy", EndStrategy, nothing),
    expression_limit = unpack_struct!(data, "ExpressionLimit", ResultLimit),
    inclusion_rules = unpack_vector!(data, "InclusionRules", InclusionRule),
    primary_criteria = unpack_struct!(data, "PrimaryCriteria", PrimaryCriteria),
    qualified_limit = unpack_struct!(data, "QualifiedLimit", ResultLimit),
    title = unpack_string!(data, "Title", nothing),
    version_range = unpack_string!(data, "cdmVersionRange", nothing))

unpack!(data::Dict) = unpack!(CohortExpression, data)

function PrettyPrinting.quoteof(obj::CohortExpression)
    ex = Expr(:call, nameof(CohortExpression))
    obj.additional_criteria === nothing || push!(ex.args, Expr(:kw, :additional_criteria, obj.additional_criteria))
    push!(ex.args, Expr(:kw, :censor_window, obj.censor_window))
    isempty(obj.censoring_criteria) || push!(ex.args, Expr(:kw, :censoring_criteria, obj.censoring_criteria))
    push!(ex.args, Expr(:kw, :collapse_settings, obj.collapse_settings))
    isempty(obj.concept_sets) || push!(ex.args, Expr(:kw, :concept_sets, obj.concept_sets))
    obj.end_strategy === nothing || push!(ex.args, Expr(:kw, :end_strategy, obj.end_strategy))
    push!(ex.args, Expr(:kw, :expression_limit, obj.expression_limit))
    isempty(obj.inclusion_rules) || push!(ex.args, Expr(:kw, :inclusion_rules, obj.inclusion_rules))
    push!(ex.args, Expr(:kw, :primary_criteria, obj.primary_criteria))
    push!(ex.args, Expr(:kw, :qualified_limit, obj.qualified_limit))
    obj.title === nothing || push!(ex.args, Expr(:kw, :title, obj.title))
    obj.version_range === nothing || push!(ex.args, Expr(:kw, :version_range, obj.version_range))
    ex
end

end
