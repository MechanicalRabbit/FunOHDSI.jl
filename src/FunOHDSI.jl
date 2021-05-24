module FunOHDSI

include("model.jl")
include("source.jl")
include("concept.jl")

module Legacy
include("legacy/cohort.jl")
include("legacy/java.jl")
include("legacy/translate.jl")
end

end
