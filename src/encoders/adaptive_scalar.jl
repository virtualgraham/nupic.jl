using Printf

abstract type AbstractAdaptiveScalarEncoder <: AbstractScalarEncoder end

mutable struct AdaptiveScalarEncoder <: AbstractAdaptiveScalarEncoder
    super::ScalarEncoder
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
        learning_enabled = true
        record_num = 0
        sliding_window = MovingAverage(300)
        
        return new(
            super,
            learning_enabled,
            record_num,
            sliding_window
        )
    end
end


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
        return get_bucket_indices(encoder.super, input)
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

    encode_into_array(encoder.super, input, output)
end


function get_bucket_info(encoder::AbstractAdaptiveScalarEncoder, buckets)
    if encoder.minval === nothing || encoder.minval === nothing
        return [(value=0, scalar=0, encoding=zeros(encoder.n))]
    end
    return get_bucket_info(encoder.super, buckets)
end


function top_down_compute(encoder::AbstractAdaptiveScalarEncoder, encoded)
    if encoder.minval === nothing || encoder.minval === nothing
        return [(value=0, scalar=0, encoding=zeros(encoder.n))]
    end
    return top_down_compute(encoder.super, encoded)
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