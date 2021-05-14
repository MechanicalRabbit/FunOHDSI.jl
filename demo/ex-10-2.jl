# Exercise 10.2 from the Book of OHDSI
# https://ohdsi.github.io/TheBookOfOhdsi/Cohorts.html#exr:exerciseCohortsSql
#
# - An occurrence of a myocardial infarction diagnose (concept 4329847
#   “Myocardial infarction” and all of its descendants, excluding concept 314666
#   “Old myocardial infarction” and any of its descendants).
# - During an inpatient or ER visit (concepts 9201, 9203, and 262 for
#   “Inpatient visit”, “Emergency Room Visit”, and “Emergency Room and Inpatient
#   Visit”, respectively).

using FunSQL:
    FunSQL, @dissect, Agg, As, Bind, Define, From, FUN, Fun, FunctionNode, Get,
    Group, Join, LeftJoin, LIT, OP, Select, SQLClause, SQLTable, Partition,
    Var, Where, render
using ODBC
using DataFrames
using Dates
using FunOHDSI: Model

const model = Model()

function FunSQL.translate(::Val{:+}, n::FunctionNode, treq)
    args = FunSQL.translate(n.args, treq)
    if length(args) == 2 && FunSQL.@dissect args[2] LIT(val = val)
        if val isa Dates.Day
            if treq.ctx.dialect.name === :postgresql || treq.ctx.dialect.name === :redshift
                return OP(:+, args = [args[1], LIT(val.value)])
            elseif treq.ctx.dialect.name === :sqlserver
                return FUN(:DATEADD, args = [OP(:day), LIT(val.value), args[1]])
            end
        end
    end
    FunSQL.translate_default(n, treq)
end

function FunSQL.translate(::Val{:-}, n::FunctionNode, treq)
    args = FunSQL.translate(n.args, treq)
    if length(args) == 2 && FunSQL.@dissect args[2] LIT(val = val)
        if val isa Dates.Day
            if treq.ctx.dialect.name === :postgresql || treq.ctx.dialect.name === :redshift
                return OP(:-, args = [args[1], LIT(val.value)])
            elseif treq.ctx.dialect.name === :sqlserver
                return FUN(:DATEADD, args = [OP(:day), LIT(- val.value), args[1]])
            end
        end
    end
    FunSQL.translate_default(n, treq)
end

function FunSQL.render(ctx, val::Bool)
    if ctx.dialect.name === :sqlserver
        print(ctx, val ? 1 : 0)
    else
        print(ctx, val ? "TRUE" : "FALSE")
    end
end

const dsn = ENV["FUNOHDSI_DSN"]
const conn = ODBC.Connection(dsn)

const dialect = Symbol(ENV["FUNOHDSI_DIALECT"])
@assert dialect in (:postgresql, :redshift, :sqlserver)

function run(q)
    println('-' ^ 80)
    display(q)
    println()
    println()
    sql = render(q, dialect = dialect)
    println(sql, ';')
    println()
    @time res = DBInterface.execute(conn, sql)
    println()
    println(IOContext(stdout, :limit => true), DataFrame(res))
end

CONCEPT(vocabulary, code) =
    (vocabulary = vocabulary, code = code)

CONCEPT(vocabulary, codes...) =
    [CONCEPT(vocabulary, code) for code in codes]

SNOMED(codes...) =
    CONCEPT("SNOMED", codes...)

VISIT(codes...) =
    CONCEPT("Visit", codes...)

const myocardial_infarction = SNOMED("22298006")

const old_myocardial_infarction = SNOMED("1755008")

const inpatient_or_er = VISIT("ERIP", "ER", "IP")

HasCode(c) =
    Fun.and(Get.vocabulary_id .== c.vocabulary,
            Get.concept_code .== c.code)

HasCode(cs::AbstractVector) =
    Fun.or(args = [HasCode(c) for c in cs])

FromConcept() =
    From(model.concept) |>
    Where(Fun."is null"(Get.invalid_reason))

FromConcept(c; exclude = nothing) =
    FromConcept(c, exclude)

FromConcept(c, ::Nothing) =
    FromConcept() |>
    Join(:descendant_x_ancestor => model.concept_ancestor,
         Get.concept_id .== Get.descendant_x_ancestor.descendant_concept_id) |>
    Join(:ancestor => FromConcept() |>
                      Where(HasCode(c)),
         Get.descendant_x_ancestor.ancestor_concept_id .== Get.ancestor.concept_id)
    Group(Get.concept_id)

FromConcept(ic, ec) =
    FromConcept(ic) |>
    LeftJoin(:excluded => FromConcept(ec),
             Get.concept_id .== Get.excluded.concept_id) |>
    Where(Fun."is null"(Get.excluded.concept_id))

Infarction =
    FromConcept(myocardial_infarction, exclude = old_myocardial_infarction)

run(Infarction)

InpatientOrER = FromConcept(inpatient_or_er)

run(InpatientOrER)

InfarctionCondition =
    From(model.condition_occurrence) |>
    Join(:concept => Infarction,
         Get.condition_concept_id .== Get.concept.concept_id) |>
    Define(:start_date => Get.condition_start_date,
           :end_date => Get.condition_start_date .+ Day(7))

InfarctionCondition |>
Select(Get.person_id, Get.start_date, Get.end_date) |>
run

#=
InfarctionCondition′ =
    From(model.condition_occurrence) |>
    Where(Fun.in(Get.condition_concept_id,
                 Infarction |> Select(Get.concept_id))) |>
    Define(:start_date => Get.condition_start_date,
           :end_date => Get.condition_start_date .+ 7)

InfarctionCondition′ |>
Select(Get.person_id, Get.start_date, Get.end_date) |>
run
=#

InfarctionConditionInObservationPeriod =
    InfarctionCondition |>
    Join(:op => model.observation_period,
         Fun.and(Get.person_id .== Get.op.person_id,
                 Get.op.observation_period_start_date .<= Get.start_date,
                 Get.start_date .<= Get.op.observation_period_end_date)) |>
    Define(:end_date => Fun.case(Get.end_date .<= Get.op.observation_period_end_date,
                                 Get.end_date,
                                 Get.op.observation_period_end_date))

InfarctionConditionInObservationPeriod |>
Select(Get.person_id,
       Get.op.observation_period_start_date,
       Get.start_date,
       Get.end_date,
       Get.op.observation_period_end_date) |>
run

AcuteVisit =
    From(model.visit_occurrence) |>
    Join(:concept => InpatientOrER,
         Get.visit_concept_id .== Get.concept.concept_id)

AcuteVisit |>
run

#=
AcuteVisit′ =
    From(model.visit_occurrence) |>
    Where(Fun.in(Get.visit_concept_id,
                 InpatientOrER |> Select(Get.concept_id)))

AcuteVisit′ |>
run
=#

CorrelatedAcuteVisit(PersonId, IndexDate, OPStartDate, OPEndDate) =
    AcuteVisit |>
    Where(Fun.and(Fun."="(Get.person_id, Var.person_id),
                  Fun."<="(Var.op_start_date, Get.visit_start_date),
                  Fun."<="(Get.visit_end_date, Var.op_end_date),
                  Fun."<="(Get.visit_start_date, Var.index_date),
                  Fun."<="(Var.index_date, Get.visit_end_date))) |>
    Bind(:person_id => PersonId,
         :index_date => IndexDate,
         :op_start_date => OPStartDate,
         :op_end_date => OPEndDate)

const selected_person_id = 42891

CorrelatedAcuteVisit(selected_person_id, Date(2008, 02, 01), Date(2008), Date(2009)) |>
run

if dialect === :postgresql || dialect === :sqlserver
    InfarctionConditionDuringAcuteVisit =
        InfarctionConditionInObservationPeriod |>
        Where(Fun.exists(CorrelatedAcuteVisit(Get.person_id,
                                              Get.start_date,
                                              Get.op.observation_period_start_date,
                                              Get.op.observation_period_end_date)))

    InfarctionConditionDuringAcuteVisit |>
    run
end

if dialect === :redshift
    InfarctionConditionDuringAcuteVisit =
        InfarctionConditionInObservationPeriod |>
        Join(:visit => AcuteVisit,
             Fun.and(Fun."="(Get.visit.person_id, Get.person_id),
                      Fun."<="(Get.op.observation_period_start_date, Get.visit.visit_start_date),
                      Fun."<="(Get.visit.visit_end_date, Get.op.observation_period_end_date),
                      Fun."<="(Get.visit.visit_start_date, Get.start_date),
                      Fun."<="(Get.start_date, Get.visit.visit_end_date)))

    InfarctionConditionDuringAcuteVisit |>
    run
end

InfarctionConditionDuringAcuteVisit |>
Where(Get.person_id .== selected_person_id) |>
run

if dialect === :postgresql || dialect === :sqlserver
    CollapseIntervals(gap) =
        Define(:end_date => Get.end_date .+ gap) |>
        Partition(Get.person_id, order_by = [Get.start_date]) |>
        Define(:boundary => Agg.lag(Get.end_date)) |>
        Define(:bump => Fun.case(Get.start_date .<= Get.boundary, 0, 1)) |>
        Partition(Get.person_id, order_by = [Get.start_date]) |>
        Define(:group => Agg.sum(Get.bump)) |>
        Group(Get.person_id, Get.group) |>
        Define(:start_date => Agg.min(Get.start_date),
               :end_date => Agg.max(Get.end_date) .- gap)
end

if dialect === :redshift
    CollapseIntervals(gap) =
        Define(:end_date => Get.end_date .+ gap) |>
        Partition(Get.person_id, order_by = [Get.start_date]) |>
        Define(:boundary => Agg.lag(Get.end_date)) |>
        Define(:bump => Fun.case(Get.start_date .<= Get.boundary, 0, 1)) |>
        Partition(Get.person_id, order_by = [Get.start_date, .- Get.bump]) |>
        Define(:group => Agg.sum(Get.bump, frame = :rows)) |>
        Group(Get.person_id, Get.group) |>
        Define(:start_date => Agg.min(Get.start_date),
               :end_date => Agg.max(Get.end_date) .- gap)
end

InfarctionCohort =
    InfarctionConditionDuringAcuteVisit |>
    CollapseIntervals(Day(180)) |>
    Select(Get.person_id, Get.start_date, Get.end_date)

InfarctionCohort |>
Where(Get.person_id .== selected_person_id) |>
run

InfarctionCohort |>
run

