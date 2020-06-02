using Random


abstract type AbstractCoordinateEncoder <: AbstractEncoder end

mutable struct CoordinateEncoder <: AbstractCoordinateEncoder
    super::Encoder
    w::Integer
    n::Integer
    verbosity::Integer

    function CoordinateEncoder(
        w::Integer=21,
        n::Integer=1000,
        name::String=nothing,
        verbosity::Integer=0
    )
        if w <= 0 || w % 2 == 0
            error("w must be an odd positive integer")
        end

        if n <= 6*w
            error("n must be an int strictly greater than 6*w. For good results we recommend n be strictly greater than 11*w")
        end

        super = Encoder(name)

        return new(
            super,
            w,
            n,
            verbosity
        )
    end
end


get_width(encoder::AbstractCoordinateEncoder) = encoder.n
get_description(encoder::AbstractCoordinateEncoder) = [("coordinate", 0), ("radius", 1)]
get_scalars(encoder::AbstractCoordinateEncoder, input_data) = zeros(length(input_data))


function encode_into_array(encoder::AbstractCoordinateEncoder, input_data, output::AbstractArray{Bool}; learn=nothing)
    coordinate, radius = input_data

    @assert radius isa Integer

    neighbors = neighbors(coordinate, radius)
    winners = top_w_coordinates(neighbors, encoder.w)

    bit_fn = coordinate -> bit_for_coordinate(coordinate, encoder.n)
    indices = [bit_fn for w in winners]
    
    output[:] .= 0
    output[indices] = 1
end


function neighbors(coordinate, radius)
    ranges = [n-radius:n+radius for n in coordinate]
    vcat(Iterators.product(ranges...)...)
end


function top_w_coordinates(coordinates, w)
    orders = [order_for_coordinate(c) for c in coordinates]
    indices = sortperm(orders)
    coordinates[indices[lastindex(indices)-w+1:lastindex(indices)]]
end


function hash_coordinate(coordinate)
    coordinate_string = join([v for v in coordinate], ", ")
    hash(coordinate_string)
end


function order_for_coordinate(coordinate)
    seed = hash_coordinate(coordinate)
    rng = MersenneTwister(seed)
    rand(rng, Float64)
end


function bit_for_coordinate(coordinate, n)
    seed = hash_coordinate(coordinate)
    rng = MersenneTwister(seed)
    rand(rng, 1:n)
end


function Base.show(io::IO, encoder::CoordinateEncoder)
    println(io,
        """
        CoordinateEncoder:
        w: $(encoder.w)
        n: $(encoder.n)
        """
    )
end