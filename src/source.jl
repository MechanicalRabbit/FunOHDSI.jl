
using FunSQL: SQLTable, SQLCatalog

const POSTGRESQL_DRIVER = "/usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so"
const REDSHIFT_DRIVER = "/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so"
const SQLSERVER_DRIVER = "/usr/lib/libmsodbcsql-18.so"

function DSN(;
             dialect,
             host = nothing,
             port = nothing,
             user = nothing,
             password = nothing,
             database = nothing)
    @assert dialect in (:postgresql, :redshift, :sqlserver)
    if dialect === :postgresql
        dsn = "Driver=$POSTGRESQL_DRIVER"
        host === nothing || (dsn *= ";Server=$host")
        port === nothing || (dsn *= ";Port=$port")
        user === nothing || (dsn *= ";UID=$user")
        password === nothing || (dsn *= ";PWD=$password")
        database === nothing || (dsn *= ";Database=$database")
    elseif dialect === :redshift
        dsn = "Driver=$REDSHIFT_DRIVER"
        host === nothing || (dsn *= ";Host=$host")
        port === nothing || (dsn *= ";Port=$port")
        user === nothing || (dsn *= ";UID=$user")
        password === nothing || (dsn *= ";PWD=$password")
        database === nothing || (dsn *= ";Database=$database")
    elseif dialect == :sqlserver
        dsn = "Driver=$SQLSERVER_DRIVER"
        host === nothing || (dsn *= ";Server=$host")
        host === nothing || port === nothing || (dsn *= ",$port")
        user === nothing || (dsn *= ";UID=$user")
        password === nothing || (dsn *= ";PWD=$password")
        database === nothing || (dsn *= ";Database=$database")
    end
    dsn
end

struct Source
    dialect::Symbol
    dsn::String
    model::Model
    catalog::SQLCatalog

    function Source(; dialect = nothing, dsn = nothing, model = nothing)
        if dialect === nothing
            dialect = Symbol(ENV["FUNOHDSI_DIALECT"])
        end
        if !(dsn isa AbstractString)
            if dsn === nothing
                dsn = ENV["FUNOHDSI_DSN"]
            else
                dsn = DSN(; dialect = dialect, dsn...)
            end
        end
        if !(model isa Model)
            if model === nothing
                model = (;)
            end
            model = Model(; model...)
        end
        tables = Dict{Symbol, SQLTable}()
        for name in fieldnames(Model)
            tbl = getproperty(model, name)
            tbl !== nothing || continue
            tables[name] = tbl
        end
        catalog = SQLCatalog(tables = tables, dialect = dialect)
        new(dialect, dsn, model, catalog)
    end
end

