abstract type AbstractDeltaEncoder <: AbstractAdaptiveScalarEncoder end

mutable struct DeltaEncoder <: AbstractDeltaEncoder
    adaptive_scalar_encoder:: AdaptiveScalarEncoder
    learning_enabled
    state_lock
    width
    encoders
    description
    name
    n
    prev_absolute
    prev_delta

    function DeltaEncoder(
        w::Integer,
        minval::Union{Number, Nothing},
        maxval::Union{Number, Nothing},
        n::Integer;
        name::Union{String, Nothing}=nothing,
        verbosity=0,
        forced::Bool=false
    )

        adaptive_scalar_encoder = AdaptiveScalarEncoder(
            w,
            minval,
            maxval,
            n;
            name=name,
            verbosity=verbosity,
            clip_input=true,
            forced=forced
        )

        @assert n != 0
        
        learning_enabled = false
        state_lock = false
        width = n
        encoders = nothing
        description = []
        prev_absolute = nothing
        prev_delta = nothing

        return new(
            adaptive_scalar_encoder,
            learning_enabled,
            state_lock,
            width,
            encoders,
            description,
            name,
            n,
            prev_absolute,
            prev_delta
        )
    end
end

## Boilerplate code to emulate inheretance 
Base.getproperty(encoder::AbstractDeltaEncoder, s::Symbol) = get(encoder, Val(s))
get(encoder::AbstractDeltaEncoder, ::Val{T}) where {T}  = getfield(encoder, T) # fall back to getfield
get(encoder::AbstractDeltaEncoder, ::Val{:scalar_encoder}) = encoder.adaptive_scalar_encoder.scalar_encoder
get(encoder::AbstractDeltaEncoder, ::Val{:record_num}) = encoder.adaptive_scalar_encoder.record_num
get(encoder::AbstractDeltaEncoder, ::Val{:sliding_window}) = encoder.adaptive_scalar_encoder.sliding_window

Base.setproperty!(encoder::AbstractDeltaEncoder, s::Symbol, x) = set!(encoder, Val(s), x)
set!(encoder::AbstractDeltaEncoder, ::Val{T}, x) where {T}  = setfield!(encoder, T, x) # fall back to getfield
set!(encoder::AbstractDeltaEncoder, ::Val{:record_num}, x) = encoder.scalar_encoder.record_num = x
set!(encoder::AbstractDeltaEncoder, ::Val{:sliding_window}, x) = encoder.scalar_encoder.sliding_window = x

function encode_into_array(encoder::AbstractDeltaEncoder, input, output::BitArray; learn=nothing)
    if learn === nothing
        learn = encoder.learning_enabled
    end
    if input === nothing
        output[1:encoder.n] .= 0
    else 
        if encoder.prev_absolute === nothing
            encoder.prev_absolute = input
        end
        delta = input - encoder.prev_absolute
        encode_into_array(encoder.adaptive_scalar_encoder, delta, output; learn=learn)
        if !encoder.state_lock
            encoder.prev_absolute = input
            encoder.prev_delta = delta
        end
    end
end

set_state_lock(encoder::AbstractDeltaEncoder, lock) = encoder.state_lock = lock

set_field_stats!(encoder::AbstractDeltaEncoder, field_name, field_stats) = nothing

# get_bucket_indices(encoder::AbstractDeltaEncoder, input; learn=nothing) = get_bucket_indices(encoder.adaptive_scalar_encoder, input; learn=learn)

# get_bucket_info(encoder::AbstractDeltaEncoder, buckets) = get_bucket_info(encoder.adaptive_scalar_encoder, buckets)

function top_down_compute(encoder::AbstractDeltaEncoder, encoded)
    if encoder.prev_absolute === nothing || encoder.prev_delta === nothing 
        return [(value=0, scalar=0, encoding=zeros(encoder.n))]
    end
    ret = top_down_compute(encoder.adaptive_scalar_encoder, encoded)
    if encoder.prev_absolute !== nothing
        ret = [(value=ret[1].value+encoder.prev_absolute, scalar=ret[1].scalar+encoder.prev_absolute, encoding=ret[1].encoding)]
    end
    return ret
end