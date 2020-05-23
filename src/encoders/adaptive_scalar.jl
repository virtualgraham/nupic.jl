abstract type AbstractAdaptiveScalarEncoder <: AbstractScalarEncoder end

mutable struct AdaptiveScalarEncoder <: AbstractAdaptiveScalarEncoder
    super::ScalarEncoder
    _learningEnabled::Bool
    recordNum
    slidingWindow

    function AdaptiveScalarEncoder(
        w::Integer,
        minval::Union{Number, Nothing},
        maxval::Union{Number, Nothing},
        n::Integer;
        name::Union{String, Nothing}=nothing,
        verbosity=0,
        clip_input::Bool=false,
        forced::Bool=false
    )
        super = ScalarEncoder(
            w,
            minval,
            maxval;
            periodic=false,
            n=n,
            radius=DEFAULT_RADIUS,
            resolution=DEFAULT_RESOLUTION,
            name=name,
            verbosity=verbosity,
            clip_input=clip_input,
            forced=forced,
        )

        _learningEnabled = true
        recordNum = 0
        slidingWindow = nothing
        
        return new(
            super,
            _learningEnabled,
            recordNum,
            slidingWindow
        )
    end
end

Base.getproperty(encoder::AdaptiveScalarEncoder, s::Symbol) = get(encoder, Val(s))
get(encoder::AdaptiveScalarEncoder, ::Val{T}) where {T}  = getfield(encoder, T) # fall back to getfield
get(encoder::AdaptiveScalarEncoder, ::Val{:w}) = encoder.super.w
get(encoder::AdaptiveScalarEncoder, ::Val{:minval}) = encoder.super.minval
get(encoder::AdaptiveScalarEncoder, ::Val{:maxval}) = encoder.super.maxval
get(encoder::AdaptiveScalarEncoder, ::Val{:periodic}) = encoder.super.periodic
get(encoder::AdaptiveScalarEncoder, ::Val{:n}) = encoder.super.n
get(encoder::AdaptiveScalarEncoder, ::Val{:radius}) = encoder.super.radius
get(encoder::AdaptiveScalarEncoder, ::Val{:resolution}) = encoder.super.resolution
get(encoder::AdaptiveScalarEncoder, ::Val{:name}) = encoder.super.name
get(encoder::AdaptiveScalarEncoder, ::Val{:verbosity}) = encoder.super.verbosity
get(encoder::AdaptiveScalarEncoder, ::Val{:clip_input}) = encoder.super.clip_input
get(encoder::AdaptiveScalarEncoder, ::Val{:encoders}) = encoder.super.encoders
get(encoder::AdaptiveScalarEncoder, ::Val{:halfwidth}) = encoder.super.halfwidth
get(encoder::AdaptiveScalarEncoder, ::Val{:range}) = encoder.super.range
get(encoder::AdaptiveScalarEncoder, ::Val{:range_internal}) = encoder.super.range_internal
get(encoder::AdaptiveScalarEncoder, ::Val{:n_internal}) = encoder.super.n_internal
get(encoder::AdaptiveScalarEncoder, ::Val{:_top_down_mapping_m}) = encoder.super._top_down_mapping_m
get(encoder::AdaptiveScalarEncoder, ::Val{:_top_down_values}) = encoder.super._top_down_values
get(encoder::AdaptiveScalarEncoder, ::Val{:_bucket_values}) = encoder.super._bucket_values
get(encoder::AdaptiveScalarEncoder, ::Val{:padding}) = encoder.super.padding
get(encoder::AdaptiveScalarEncoder, ::Val{:flattened_field_type_list}) = encoder.super.flattened_field_type_list
get(encoder::AdaptiveScalarEncoder, ::Val{:flattened_encoder_list}) = encoder.super.flattened_encoder_list


Base.setproperty!(encoder::AdaptiveScalarEncoder, s::Symbol, x) = set!(encoder, Val(s), x)
set!(encoder::AdaptiveScalarEncoder, ::Val{T}, x) where {T}  = setfield!(encoder, T, x) # fall back to getfield

function set!(encoder::AdaptiveScalarEncoder, ::Val{:_top_down_values}, x)
    encoder.super._top_down_values = x
end

function set!(encoder::AdaptiveScalarEncoder, ::Val{:_top_down_mapping_m}, x)
    encoder.super._top_down_mapping_m = x
end

function set!(encoder::AdaptiveScalarEncoder, ::Val{:_bucket_values}, x)
    encoder.super._bucket_values = x
end

function set!(encoder::AdaptiveScalarEncoder, ::Val{:flattened_encoder_list}, x)
    encoder.super.flattened_encoder_list = x
end

function set!(encoder::AdaptiveScalarEncoder, ::Val{:flattened_field_type_list}, x)
    encoder.super.flattened_field_type_list = x
end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:range_internal}, x)
#     encoder.super.range_internal = x
# end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:maxval}, x)
#     encoder.super.maxval = x
# end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:minval}, x)
#     encoder.super.minval = x
# end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:resolution}, x)
#     encoder.super.resolution = x
# end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:radius}, x)
#     encoder.super.radius = x
# end

# function set!(encoder::AdaptiveScalarEncoder, ::Val{:range}, x)
#     encoder.super.range = x
# end




function set_encoder_params(encoder::AdaptiveScalarEncoder)

end


function set_field_stats(encoder::AdaptiveScalarEncoder)

end


function _set_min_and_max(encoder::AdaptiveScalarEncoder)

end


function get_bucket_indices(encoder::AdaptiveScalarEncoder)

end


function encode_into_array(encoder::AdaptiveScalarEncoder)

end


function get_bucket_info(encoder::AdaptiveScalarEncoder)

end


function top_down_compute(encoder::AdaptiveScalarEncoder)

end


function Base.show(io::IO, encoder::AdaptiveScalarEncoder)
    println(io,
        """
        ScalarEncoder:
        min: $(encoder.minval)
        max: $(encoder.maxval)
        w: $(encoder.w)
        n: $(encoder.n)
        resolution: $(encoder.resolution)
        radius: $(encoder.radius)
        periodic: $(encoder.periodic)
        n_internal: $(encoder.n_internal)
        range_internal: $(encoder.range_internal)
        padding: $(encoder.padding)
        """
    )
end