abstract type AbstractCoordinateEncoder <: AbstractEncoder end

mutable struct CoordinateEncoder <: AbstractCoordinateEncoder
    super::Encoder
    w
    n
    verbosity

    function CoordinateEncoder(
        w=21,
        n=1000;
        name=nothing,
        verbosity=0
    )
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


function encode_into_array(encoder::AbstractCategoryEncoder, input, output::BitArray; learn=nothing)

end


function neighbors(coordinate, radius)

end


function top_w_coordinates(cls, coordinates, w)

end


function has_coordinate(coordinate)

end


function order_for_coordinate(cls, coordinate)

end


function bit_for_coordinate(cls, coordinate, n)

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