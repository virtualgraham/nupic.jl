using Printf

abstract type AbstractAdaptiveScalarEncoder <: AbstractScalarEncoder end

mutable struct AdaptiveScalarEncoder <: AbstractAdaptiveScalarEncoder
    scalar_encoder::ScalarEncoder
    learning_enabled::Bool
    record_num::Integer
    sliding_window::MovingAverage

    function AdaptiveScalarEncoder(
        w::Integer,
        minval::Union{Number, Nothing},
        maxval::Union{Number, Nothing},
        n::Integer;
        name::Union{String, Nothing}=nothing,
        verbosity=0,
        clip_input::Bool=true,
        forced::Bool=false
    )
        scalar_encoder = ScalarEncoder(
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
        learning_enabled = true
        record_num = 0
        sliding_window = MovingAverage(300)
        
        return new(
            scalar_encoder,
            learning_enabled,
            record_num,
            sliding_window
        )
    end
end

## Boilerplate code to emulate inheretance 
Base.getproperty(encoder::AbstractAdaptiveScalarEncoder, s::Symbol) = get(encoder, Val(s))
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{T}) where {T}  = getfield(encoder, T) # fall back to getfield
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:w}) = encoder.scalar_encoder.w
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:minval}) = encoder.scalar_encoder.minval
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:maxval}) = encoder.scalar_encoder.maxval
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:periodic}) = encoder.scalar_encoder.periodic
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:n}) = encoder.scalar_encoder.n
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:radius}) = encoder.scalar_encoder.radius
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:resolution}) = encoder.scalar_encoder.resolution
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:name}) = encoder.scalar_encoder.name
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:verbosity}) = encoder.scalar_encoder.verbosity
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:clip_input}) = encoder.scalar_encoder.clip_input
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:encoders}) = encoder.scalar_encoder.encoders
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:halfwidth}) = encoder.scalar_encoder.halfwidth
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:range}) = encoder.scalar_encoder.range
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:range_internal}) = encoder.scalar_encoder.range_internal
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:n_internal}) = encoder.scalar_encoder.n_internal
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_top_down_mapping_m}) = encoder.scalar_encoder._top_down_mapping_m
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_top_down_values}) = encoder.scalar_encoder._top_down_values
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_bucket_values}) = encoder.scalar_encoder._bucket_values
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:padding}) = encoder.scalar_encoder.padding
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:flattened_field_type_list}) = encoder.scalar_encoder.flattened_field_type_list
get(encoder::AbstractAdaptiveScalarEncoder, ::Val{:flattened_encoder_list}) = encoder.scalar_encoder.flattened_encoder_list

Base.setproperty!(encoder::AdaptiveScalarEncoder, s::Symbol, x) = set!(encoder, Val(s), x)
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{T}, x) where {T}  = setfield!(encoder, T, x) # fall back to getfield
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_top_down_values}, x) = encoder.scalar_encoder._top_down_values = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_top_down_mapping_m}, x) = encoder.scalar_encoder._top_down_mapping_m = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:_bucket_values}, x) = encoder.scalar_encoder._bucket_values = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:flattened_encoder_list}, x) = encoder.scalar_encoder.flattened_encoder_list = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:flattened_field_type_list}, x) = encoder.scalar_encoder.flattened_field_type_list = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:range_internal}, x) = encoder.scalar_encoder.range_internal = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:resolution}, x) = encoder.scalar_encoder.resolution = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:radius}, x) = encoder.scalar_encoder.radius = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:range}, x) = encoder.scalar_encoder.range = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:n_internal}, x) = encoder.scalar_encoder.n_internal = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:maxval}, x) = encoder.scalar_encoder.maxval = x
set!(encoder::AbstractAdaptiveScalarEncoder, ::Val{:minval}, x) = encoder.scalar_encoder.minval = x


function _set_encoder_params!(encoder::AbstractAdaptiveScalarEncoder)
    encoder.range_internal = encoder.maxval - encoder.minval

    encoder.resolution = encoder.range_internal / (encoder.n - encoder.w)
    encoder.radius = encoder.w * encoder.resolution
    encoder.range = encoder.range_internal + encoder.resolution

    encoder.n_internal = encoder.n - 2 * encoder.padding

    encoder._bucket_values = nothing
end


function set_field_stats!(encoder::AbstractAdaptiveScalarEncoder, field_name, field_stats)
    if field_stats[field_name]["min"] === nothing || field_stats[field_name]["max"] === nothing
        return
    end
    encoder.minval = field_stats[field_name]["min"]
    encoder.maxval = field_stats[field_name]["max"]
    if encoder.minval == encoder.maxval
        encoder.maxval += 1
    end
    _set_encoder_params!(encoder)
end


function _set_min_and_max!(encoder::AbstractAdaptiveScalarEncoder, input, learn)
    next(encoder.sliding_window, input)
    if encoder.minval === nothing && encoder.maxval === nothing
        encoder.minval = input
        encoder.maxval = input + 1
        _set_encoder_params!(encoder)
    elseif learn
        sorted = get_sliding_window(encoder.sliding_window)
        sort!(sorted)

        min_over_window = sorted[1]
        max_over_window = sorted[lastindex(sorted)]

        if min_over_window < encoder.minval
            if encoder.verbosity >= 2
                @printf("Input %s=%.2f smaller than minval %.2f. Adjusting minval to %.2f", encoder.name, input, encoder.minval, encoder.min_over_window)
            end
            encoder.minval = min_over_window
            _set_encoder_params!(encoder)
        end

        if max_over_window > encoder.maxval
            if encoder.verbosity >= 2
                @printf("Input %s=%.2f greater than maxval %.2f. Adjusting maxval to %.2f", encoder.name, input, encoder.maxval, encoder.max_over_window)
            end
            encoder.maxval = max_over_window
            _set_encoder_params!(encoder)
        end
    end
end


function get_bucket_indices(encoder::AbstractAdaptiveScalarEncoder, input; learn=nothing)
    encoder.record_num += 1
    if learn === nothing
        learn = encoder.learning_enabled
    end

    if input !== nothing && isnan(input) 
       input = nothing
    end

    if input === nothing
        return [nothing]
    else
        _set_min_and_max!(encoder, input, learn)
        return get_bucket_indices(encoder.scalar_encoder, input)
    end
end


function encode_into_array(encoder::AbstractAdaptiveScalarEncoder, input, output::BitArray; learn=nothing)
    encoder.record_num += 1
    if learn === nothing
        learn = encoder.learning_enabled
    end
    if input === nothing
        output[1:encoder.n] .= 0
    elseif !isnan(input)
        _set_min_and_max!(encoder, input, learn)
    end

    encode_into_array(encoder.scalar_encoder, input, output)
end


function get_bucket_info(encoder::AbstractAdaptiveScalarEncoder, buckets)
    if encoder.minval === nothing || encoder.minval === nothing
        return [(value=0, scalar=0, encoding=zeros(encoder.n))]
    end
    return get_bucket_info(encoder.scalar_encoder, buckets)
end


function top_down_compute(encoder::AbstractAdaptiveScalarEncoder, encoded)
    if encoder.minval === nothing || encoder.minval === nothing
        return [(value=0, scalar=0, encoding=zeros(encoder.n))]
    end
    return top_down_compute(encoder.scalar_encoder, encoded)
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