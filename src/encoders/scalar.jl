using Printf
using SparseArrays

import Base.show

abstract type AbstractScalarEncoder <: Encoder end

const DEFAULT_RESOLUTION = 0
const DEFAULT_RADIUS = 0


mutable struct ScalarEncoder <: AbstractScalarEncoder
    w::Integer
    minval::Union{Float64, Nothing}
    maxval::Union{Float64, Nothing}
    periodic::Bool
    n::Integer
    radius::Float64
    resolution::Float64
    name::String
    verbosity::Integer
    clip_input::Bool

    encoders
    halfwidth::Integer
    range
    range_internal::Float64
    n_internal::Integer
    _top_down_mapping_m
    _top_down_values
    _bucket_values
    padding
    
    flattened_field_type_list
    flattened_encoder_list

    function ScalarEncoder(
        w::Integer,
        minval::Union{Number, Nothing},
        maxval::Union{Number, Nothing};
        periodic::Bool=false,
        n=0,
        radius=DEFAULT_RADIUS,
        resolution=DEFAULT_RESOLUTION,
        name::Union{String, Nothing}=nothing,
        verbosity=0,
        clip_input::Bool=false,
        forced::Bool=false
    )

        if w % 2 == 0
            error("Width must be an odd number $w")
        end

        encoders = nothing
        halfwidth = Integer((w-1)/2)
        range = 0
        range_internal = 0
       
        _top_down_mapping_m = nothing
        _top_down_values = nothing

        _bucket_values = nothing

        padding = if periodic 0 else halfwidth end

        n_internal = n - 2 * padding

        if minval !== nothing && maxval != nothing
            if minval > maxval
                error(
                    "The encoder for $name is invalid. minval $minval is greater than "
                    * "or equal to maxval $maxval. minval must be strictly less "
                    * "than maxval."
                )
            end
            range_internal = maxval - minval
        end

        if n != 0
            if radius != 0 || resolution != 0
                error("Only one of n/radius/resolution can be specified for a ScalarEncoder")
            end
            @assert( n > w )

            if minval !== nothing && maxval !== nothing
                if !periodic
                    resolution = range_internal / (n - w)
                else
                    resolution = range_internal / n
                end

                radius = w * resolution

                if periodic
                    range = range_internal
                else
                    range = range_internal + resolution
                end
            end
        else
            if radius != 0
                if resolution != 0
                    error("Only one of radius/resolution can be specified for a ScalarEncoder")
                end
                resolution = radius / w
            elseif resolution != 0
                radius = resolution * w
            else
                error("One of n, radius, resolution must be specified for a ScalarEncoder")
            end

            if minval !== nothing && maxval !== nothing
                if periodic
                    range = range_internal
                else
                    range = range_internal + resolution
                end

                nfloat = w * (range / radius) + 2 * padding
                n = ceil(nfloat)
            end
        end

        if minval !== nothing && maxval !== nothing
            n_internal = n - 2 * padding
        end

        if name === nothing
            name = "[$minval:$maxval]"
        end

        if !forced 
            if w < 21
                error(
                    "Number of bits in the SDR ($w) must be >= 21 (use "
                    * "forced=True to override)."
                )
            end 
        end

        return new(
            w,
            minval,
            maxval,
            periodic,
            n,
            radius,
            resolution,
            name,
            verbosity,
            clip_input,
            encoders,
            halfwidth,
            range,
            range_internal,
            n_internal,
            _top_down_mapping_m,
            _top_down_values,
            _bucket_values,
            padding,
            nothing,
            nothing
        )
    end
end


get_decoder_output_field_types(encoder::AbstractScalarEncoder) = (Float64,)
get_width(encoder::AbstractScalarEncoder) = encoder.n
get_description(encoder::AbstractScalarEncoder) = [(encoder.name, 0)]


function _recalc_params!(encoder::AbstractScalarEncoder)
    encoder.range_internal = encoder.maxval = encoder.minval

    if !encoder.periodic
        encoder.resolution = encoder.range_internal / (encoder.n - encoder.w)
    else
        encoder.resolution = encoder.range_internal / encoder.n
    end

    encoder.radius = encoder.w * encoder.resolution

    if encoder.periodic
        encoder.range = encoder.range_internal
    else
        encoder.range = encoder.range_internal + encoder.resolution
    end
end


function _get_first_on_bit(encoder::AbstractScalarEncoder, input)
    if input === nothing
        return nothing
    else
        if input < encoder.minval
            if encoder.clip_input && !encoder.periodic
                if encoder.verbosity > 0
                    @printf("Clipped input %s=%.2f to minval %.2f", encoder.name, input, encoder.minval)
                end
                input = encoder.minval
            else
                error("input ($input) less than range ($(encoder.minval) - $(encoder.maxval))")
            end
        end

        if encoder.periodic
            if input >= encoder.maxval
                error("input ($input) greater than periodic range ($(encoder.minval) - $(encoder.maxval))")
            end
        else
            if input > encoder.maxval
                if encoder.clip_input
                    if encoder.verbosity > 0
                        @printf("Clipped input %s=%.2f to maxval %.2f", encoder.name, input, encoder.maxval)
                    end
                    input = encoder.maxval
                else
                    error("input ($input) greater than range ($(encoder.minval) - $(encoder.maxval))")
                end
            end
        end

        centerbin::Integer = if encoder.periodic
            Integer(floor((input - encoder.minval) * encoder.n_internal / encoder.range) + encoder.padding)
        else
            Integer(floor(((input - encoder.minval) + encoder.resolution/2) / encoder.resolution) + encoder.padding)
        end

        minbin = centerbin - encoder.halfwidth;
        return minbin
    end
end


function get_bucket_indices(encoder::AbstractScalarEncoder, input::Union{Nothing, Float64})
    if input === nothing || isnan(input) return [nothing] end
    
    minbin = _get_first_on_bit(encoder, input)

    if encoder.periodic
        bucket_idx = minbin + encoder.halfwidth
        if bucket_idx < 0 bucket_idx += encoder.n end
    else
        bucket_idx = minbin
    end

    return [bucket_idx + 1]
end


function encode_into_array(encoder::AbstractScalarEncoder, input, output::BitArray; learn::Bool=true)
    if input !== nothing && isnan(input) 
        input = nothing 
    end

    bucket_idx = _get_first_on_bit(encoder, input)

    if bucket_idx === nothing
        output[1:encoder.n] .= 0
    else
        output[1:encoder.n] .= 0
        minbin = bucket_idx
        maxbin = minbin + 2*encoder.halfwidth
        if encoder.periodic
            if maxbin >= encoder.n
                bottombins = maxbin - encoder.n + 1
                output[1:bottombins] .= 1
                maxbin = encoder.n - 1
            end 
            if minbin < 0
                topbins = -minbin
                output[(encoder.n - topbins + 1):encoder.n] .= 1
                minbin = 0
            end
        end

        @assert(minbin >= 0)
        @assert(maxbin < encoder.n)

        output[(minbin + 1):(maxbin + 1)] .= 1
    end

    if encoder.verbosity >= 2
        println(
            """
            input: $input
            range: $(encoder.minval) - $(encoder.maxval)
            n: $(encoder.n)
            w: $(encoder.w)
            resolution: $(encoder.resolution)
            radius: $(encoder.radius)
            periodic: $(encoder.periodic)
            output: $output
            input desc: $(decoded_to_str(encoder, decode(encoder, output)))
            """
        )
    end
end


function decode(encoder::AbstractScalarEncoder, encoded::Union{Vector{Int64}, Vector{Float64}}; parent_field_name="")
    tmp_output = BitArray( encoded[1:encoder.n] .> 0 )

    if !any(x->x>0, tmp_output)
        return Dict(), []
    end

    if encoder.verbosity >= 2
        println("raw output: $(encoded[1:encoder.n])")
    end

    return _decode(encoder, tmp_output; parent_field_name=parent_field_name)
end


function decode(encoder::AbstractScalarEncoder, encoded::BitArray; parent_field_name="")
    if !any(x->x>0, encoded)
        return Dict(), []
    end

    tmp_output = copy(encoded)

    if encoder.verbosity >= 2
        println("raw output: $(encoded[1:encoder.n])")
    end
    
    return _decode(encoder, tmp_output; parent_field_name=parent_field_name)
end


function _decode(encoder::AbstractScalarEncoder, tmp_output::BitArray; parent_field_name="")
    max_zeros_in_a_row = encoder.halfwidth
    for i in 1:max_zeros_in_a_row 
        search_str = ones(i + 2)
        search_str[2:lastindex(search_str)-1] .= 0
        sub_len = length(search_str)

        if encoder.periodic
            for j in 1:encoder.n
                output_indices = collect(j:j+sub_len-1)
                output_indices = map(x -> (x-1) % encoder.n + 1, output_indices)
                if search_str == tmp_output[output_indices]
                    tmp_output[output_indices] .= 1
                end
            end
        else
            for j in 1:(encoder.n - sub_len + 1)
                if search_str == tmp_output[j:(j + sub_len - 1)]
                    tmp_output[j:j + sub_len - 1] .= 1
                end
            end
        end
    end

    if encoder.verbosity >= 2
        println("filtered output: $tmp_output")
    end

    nz = findall(x->x>0, tmp_output) 
    runs = []
    run = [nz[1]-1, 1]
    i = 2
    while i <= length(nz)
        if nz[i] - 1 == run[1] + run[2]
            run[2] += 1
        else 
            push!(runs, run)
            run = [nz[i] - 1, 1]
        end
        i += 1
    end
    push!(runs, run)

    if encoder.periodic && length(runs) > 1
        if runs[1][1] == 0 && runs[lastindex(runs)][1] + runs[lastindex(runs)][2] == encoder.n
            runs[lastindex(runs)][2] += runs[1][2]
            runs = runs[2:lastindex(runs)]
        end
    end

    ranges = []
    for run in runs
        (start, run_len) = run
        if run_len <= encoder.w
            left = right = start + floor(run_len/2)
        else
            left = start + encoder.halfwidth
            right = start + run_len - 1 - encoder.halfwidth
        end

        if !encoder.periodic
            in_min = (left - encoder.padding) * encoder.resolution + encoder.minval
            in_max = (right - encoder.padding) * encoder.resolution + encoder.minval
        else
            in_min = (left - encoder.padding) * encoder.range / encoder.n_internal + encoder.minval
            in_max = (right - encoder.padding) * encoder.range / encoder.n_internal + encoder.minval
        end

        if encoder.periodic
            if in_min >= encoder.maxval
                in_min -= encoder.range
                in_max -= encoder.range
            end
        end

        if in_min < encoder.minval
            in_min = encoder.minval
        end
        if in_max < encoder.minval
            in_max = encoder.minval
        end

        if encoder.periodic && in_max >= encoder.maxval
            push!(ranges, [in_min, encoder.maxval])
            push!(ranges, [encoder.minval, in_max - encoder.range])
        else
            if in_max > encoder.maxval
                in_max = encoder.maxval
            end
            if in_min > encoder.maxval
                in_min = encoder.maxval
            end
            push!(ranges, [in_min, in_max])
        end
    end

    desc = _generate_range_description(encoder, ranges)

    if parent_field_name != ""
        field_name = "$parent_field_name.$(encoder.name)"
    else
        field_name = encoder.name
    end

    return (Dict(field_name => (ranges, desc)), [field_name])
end


function _generate_range_description(encoder::AbstractScalarEncoder, ranges)
    desc = ""
    num_ranges = length(ranges)
    for i in 1:num_ranges
        if ranges[i][1] != ranges[i][2]
            desc *= @sprintf("%.2f-%.2f", ranges[i][1], ranges[i][2])
        else
            desc *= @sprintf("%.2f", ranges[i][1])
        end
        if i < num_ranges
            desc *= ", "
        end
    end
    return desc
end


function _get_top_down_mapping!(encoder::AbstractScalarEncoder)
    # Do we need to build up our reverse mapping table?
    if encoder._top_down_mapping_m === nothing
        if encoder.periodic
            encoder._top_down_values = collect((encoder.minval + encoder.resolution / 2.0) : encoder.resolution : encoder.maxval)
        else
            encoder._top_down_values = collect(encoder.minval : encoder.resolution : (encoder.maxval + encoder.resolution / 2.0))
        end
        
        num_categories = length(encoder._top_down_values)
        encoder._top_down_mapping_m = spzeros(num_categories, encoder.n)

        output_space = BitArray(undef, encoder.n)
        for i in 1:num_categories 
            value = encoder._top_down_values[i]
            value = max(value, encoder.minval)
            value = min(value, encoder.maxval)
            encode_into_array(encoder, value, output_space; learn=false)
            encoder._top_down_mapping_m[i,:] = output_space
        end
    end

    return encoder._top_down_mapping_m
end


function get_bucket_values(encoder::AbstractScalarEncoder)
    if encoder._bucket_values === nothing
        top_down_mapping_m = _get_top_down_mapping!(encoder)
        num_buckets = size(top_down_mapping_m, 1)
        encoder._bucket_values = []
        for bucket_idx in 1:num_buckets
            push!(encoder._bucket_values, get_bucket_info(encoder, [bucket_idx])[1].value)
        end
    end

    return encoder._bucket_values
end


function get_bucket_info(encoder::AbstractScalarEncoder, buckets)
    top_down_mapping_m = _get_top_down_mapping!(encoder)

    category = buckets[1]
    encoding = encoder._top_down_mapping_m[category,:]

    if encoder.periodic
        input_val = (encoder.minval + (encoder.resolution / 2.0) + ((category-1) * encoder.resolution))
    else
        input_val = encoder.minval + ((category-1) * encoder.resolution)
    end
    
    return [(value=input_val, scalar=input_val, encoding=encoding)]
end


function top_down_compute(encoder::AbstractScalarEncoder, encoded)
    top_down_mapping_m = _get_top_down_mapping!(encoder)

    category = argmax(top_down_mapping_m * encoded)

    return get_bucket_info(encoder, [category])
end


function closeness_scores(encoder::AbstractScalarEncoder, exp_values, act_values; fractional=true)
    exp_value = exp_values[1]
    act_value = act_values[1]
    if encoder.periodic
        exp_value = exp_value % encoder.maxval
        act_value = act_value % encoder.maxval
    end

    err = abs(exp_value - act_value)
    if encoder.periodic
        err = min(err, encoder.maxval - err)
    end
    if fractional
        pct_err = err / (encoder.maxval - encoder.minval)
        pct_err = min(1.0, pct_err)
    else
        closeness = err
    end

    return [closeness]
end

function Base.:(==)(x::ScalarEncoder, y::ScalarEncoder)
    return x.minval == y.minval &&
    x.maxval == y.maxval &&
    x.w == y.w &&
    x.n == y.n &&
    x.resolution == y.resolution &&
    x.radius == y.radius &&
    x.periodic == y.periodic &&
    x.n_internal == y.n_internal &&
    x.range_internal == y.range_internal &&
    x.padding == y.padding
end

function Base.show(io::IO, encoder::ScalarEncoder)
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