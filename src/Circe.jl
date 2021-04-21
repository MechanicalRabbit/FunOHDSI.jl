module Circe

using StructTypes

struct PrimaryCriteria
    criteria_list::Vector{Criteria}
    observation_window::ObservationFilter
    primary_limit::ResultLimit

    PrimaryCriteria(criteria_list,
                    observation_window,
                    primary_limit) =
        new(something(criteria_list, [Criteria()]),
            observation_window,
            something(primary_limit, ResultLimit()))
end

StructTypes.StructType(::Type{PrimaryCriteria}) =
    StructTypes.Struct()

StructTypes.names(::Type{PrimaryCriteria}) =
    ((:criteria_list, :CriteriaList),
     (:observation_window, :ObservationWindow),
     (:primary_limit, :PrimaryCriteriaLimit))

struct CohortExpression
    version_range::Union{String, Nothing}
    title::String
    primary_criteria::PrimaryCriteria
    additional_criteria::CriteriaGroup
    concept_sets::Vector{ConceptSet}
    qualified_limit::ResultLimit
    expression_limit::ResultLimit
    inclusion_rules::Vector{InclusionRule}
    end_strategy::EndStrategy
    censoring_criteria::Vector{Criteria}
    collapse_settings::CollapseSettings
    censor_window::Period

    CohortExpression(version_range,
                     title,
                     primary_criteria,
                     additional_criteria,
                     concept_sets,
                     qualified_limit,
                     expression_limit,
                     inclusion_rules,
                     end_stragery,
                     censoring_criteria,
                     collapse_settings,
                     censor_window) =
        new(version_range,
            title,
            primary_criteria,
            additional_criteria,
            concept_sets,
            something(qualified_limit, ResultLimit()),
            something(expression_limit, ResultLimit()),
            something(inclusion_rules, InclusionRule[]),
            end_strategy,
            censoring_criteria,
            something(collapse_settings, CollapseSettings()),
            censor_window)
end

StructTypes.StructType(::Type{CohortExpression}) =
    StructTypes.Struct()

StructTypes.names(::Type{CohortExpression}) =
    ((:version_range, :cdmVersionRange),
     (:title, :Title),
     (:primary_criteria, :PrimaryCriteria),
     (:additional_criteria, :AdditionalCriteria),
     (:concept_sets, :ConceptSets),
     (:qualified_limit, :QualifiedLimit),
     (:expression_limit, :ExpressionLimit),
     (:inclusion_rules, :InclusionRules),
     (:end_strategy, :EndStrategy),
     (:censoring_criteria, :CensoringCriteria),
     (:collapse_settings, :CollapseSettings),
     (:censor_window, :CensorWindow))

end
