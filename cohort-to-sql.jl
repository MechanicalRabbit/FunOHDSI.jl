#!/usr/bin/env julia

using FunOHDSI: cohort_to_sql
using StringEncodings

function usage()
    println("Usage: $PROGRAM_FILE [dialect=postgresql] [target_cohort_id=0] ... < cohort.json")
    exit(1)
end

const parameters = Dict{Symbol, String}()
for arg in ARGS
    occursin('=', arg) || usage()
    key, val = split(arg, '=', limit = 2)
    if startswith(key, "--")
        key = key[3:end]
    end
    key = replace(key, '-' => '_')
    parameters[Symbol(key)] = val
end

const cohort = decode(read(stdin), "latin1")

sql = cohort_to_sql(cohort; parameters...)
println(sql)
