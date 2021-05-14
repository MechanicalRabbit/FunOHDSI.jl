module FunOHDSI

include("model.jl")
include("source.jl")

module Legacy
include("legacy/cohort.jl")
include("legacy/java.jl")
end

end
