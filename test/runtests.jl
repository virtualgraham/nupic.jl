using Test

using .NuPIC

# Unit Tests
println("Unit Tests")

include("unit/encoders/scalar_test.jl")
include("unit/encoders/adaptive_scalar_test.jl")
include("unit/encoders/delta_test.jl")
include("unit/encoders/category_test.jl")
include("unit/encoders/date_test.jl")