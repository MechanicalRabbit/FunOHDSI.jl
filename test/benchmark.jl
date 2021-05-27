#!/usr/bin/env julia

using FunOHDSI: Source
using FunOHDSI.Legacy: unpack!, translate, cohort_to_sql, initialize_java
using FunSQL: render, As, Select, Get, From, Fun, Join, Where, Group, Agg
using JSON
using Pkg.Artifacts
using ODBC
using StringEncodings
using Tables
using CSV

const SQL_ATTR_QUERY_TIMEOUT = 0
function setquerytimeout(h, sec)
    ret = ODBC.API.SQLSetStmtAttr(ODBC.API.getptr(h),
                                  SQL_ATTR_QUERY_TIMEOUT,
                                  sec,
                                  ODBC.API.SQL_IS_UINTEGER)
    if ret == ODBC.API.SQL_ERROR || ret == ODBC.API.SQL_INVALID_HANDLE
        error(ODBC.API.diagnostics(h))
    end
    ret
end

function execute_with_timeout(conn::ODBC.Connection, sql::AbstractString, params=(); timeout, debug::Bool=false, kw...)
    ODBC.clear!(conn)
    h = ODBC.API.Handle(ODBC.API.SQL_HANDLE_STMT, ODBC.API.getptr(conn.dbc))
    setquerytimeout(h, timeout)
    conn.stmts[h] = 0
    conn.cursorstmt = h
    ODBC.API.enableasync(h)
    bindings = ODBC.bindparams(h, params, nothing)
    debug && println("executing statement: $sql")
    GC.@preserve bindings (ODBC.API.execdirect(h, sql))
    return ODBC.Cursor(h; debug=debug, kw...)
end

function benchmark(file)
    println('-' ^ 80)
    println(file)
    cohort = basename(file)
    if endswith(cohort, ".json")
        cohort = cohort[1:end-5]
    end
    raw = read(file)
    json = decode(raw, "latin1")
    data = JSON.parse(json)
    expr = unpack!(data)
    if show_expr
        println(expr)
    end
    @assert isempty(data)
    if use_circe
        sql = cohort_to_sql(json, dialect = dialect)
    else
        sql = translate(expr, dialect = dialect, cohort_definition_id = 1)
    end
    if show_sql
        println(sql)
    end
    source !== nothing || return true
    conn = ODBC.Connection(source.dsn)
    if dialect === :redshift
        execute_with_timeout(conn, "SET statement_timeout TO $(1000timeout)", timeout = timeout)
    else
        execute_with_timeout(conn, "SELECT 1", timeout = timeout)
    end
    success = true
    elapsed = @elapsed try
        execute_with_timeout(conn, sql, timeout = timeout)
    catch err
        showerror(stdout, err)
        println()
        success = false
    end
    println("Time elapsed: $elapsed")
    if success
        q = From(source.model.cohort) |>
            Where(Get.cohort_definition_id .== (use_circe ? 0 : 1)) |>
            Group() |>
            Select(:count => Agg.count(),
                   :length => Fun.coalesce(Agg.sum(Fun.datediff_day(Get.cohort_end_date, Get.cohort_start_date) .+ 1), 0))
        total = Tables.rowtable(DBInterface.execute(conn, render(q, dialect = dialect)))
        count = total[1].count
        length = total[1].length
    else
        count = length = 0
    end
    DBInterface.close!(conn)
    (cohort = cohort, elapsed = elapsed, success = success, count = count, length = length)
end

source = Source()
dialect = source.dialect

use_circe = false
cohort_pattern = nothing
show_expr = false
show_sql = false
timeout = 1800
output = nothing
args = copy(ARGS)
while !isempty(args)
    arg = popfirst!(args)
    if arg == "--circe"
        global use_circe = true
    elseif arg == "--show-expr"
        global show_expr = true
    elseif arg == "--show-sql"
        global show_sql = true
    elseif arg == "--cohort"
        !isempty(args) || error("missing value for $arg")
        global cohort_pattern = popfirst!(args)
    elseif startswith(arg, "--cohort=")
        global cohort_pattern = arg[10:end]
    elseif arg == "-o" || args == "--output"
        !isempty(args) || error("missing value for $arg")
        global output = popfirst!(args)
    elseif startswith(arg, "-o")
        global output = arg[3:end]
    elseif startswith(arg, "--output=")
        global output = arg[10:end]
    elseif arg == "-t" || arg == "--timeout"
        !isempty(args) || error("missing value for $arg")
        global timeout = parse(Int, popfirst!(args))
    elseif startswith(arg, "-t")
        global timeout = parse(Int, arg[3:end])
    elseif startswith(arg ,"--timeout=")
        global timeout = parse(Int, arg[11:end])
    else
        error("invalid argument $arg")
    end
end

if use_circe
    initialize_java()
end

lines = (cohort = String[], elapsed = Float64[], success = Int[], count = Int[], length = Int[])
for dir in readdir(joinpath(artifact"PhenotypeLibrary", "PhenotypeLibrary-0.0.1/inst"), join = true)
    isdir(dir) || continue
    for file in readdir(dir, join = true)
        cohort_pattern == nothing || contains(file, cohort_pattern) || continue
        endswith(file, ".json") || continue
        line = benchmark(file)
        push!(lines.cohort, line.cohort)
        push!(lines.elapsed, line.elapsed)
        push!(lines.success, line.success)
        push!(lines.count, line.count)
        push!(lines.length, line.length)
    end
end

println('-' ^ 80)
CSV.write(something(output, stdout), lines)

