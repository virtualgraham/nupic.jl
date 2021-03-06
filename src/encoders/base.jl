using Printf

abstract type AbstractEncoder <: Object end

mutable struct Encoder <: AbstractEncoder
    name::String
    encoders
    flattened_encoder_list
    flattened_field_type_list

    function Encoder(
        name::String,
        encoders = nothing
    )
        return new(
            name, 
            encoders,
            nothing,
            nothing
        )
    end
end

## TO DELETE
# get_encoders(encoder::AbstractEncoder) = error("Encoder method get_encoders not implemented")
# get_name(encoder::AbstractEncoder) = error("Encoder method get_name not implemented")
# get_flattened_field_type_list(encoder::AbstractEncoder) = nothing
# set_flattened_field_type_list(encoder::AbstractEncoder, field_types) = nothing
# get_flattened_encoder_list(encoder::AbstractEncoder) = nothing
# set_flattened_encoder_list(encoder::AbstractEncoder, encoders) = nothing

## POSSIBLY DELETE
# set_learning(encoder::AbstractEncoder, learning_enabled::Bool) = nothing
# set_field_stats(encoder::AbstractEncoder) = nothing
# set_state_lock(encoder::AbstractEncoder, lock) = nothing

# Trait Methods keep documentated
# get_width(encoder::AbstractEncoder) = error("Encoder method get_width not implemented")
# get_description(encoder::AbstractEncoder) = error("getDescription must be implemented by all subtypes")
# get_bucket_values(encoder::AbstractEncoder, decoded_results) = error("getBucketValues must be implemented by all subtypes")
# encode_into_array(encoder::AbstractEncoder, input_data, output::BitArray; learn=true) = error("Encoder method encode_into_array not implemented")


function encode(this::AbstractEncoder, input_data)
    output = BitArray(Iterators.repeated(0, get_width(this)))
    encode_into_array(this, input_data, output)
    return output
end


function get_scaler_names(this::AbstractEncoder; parent_field_name="") 
    names = String[]

    encoders = this.encoders

    if encoders !== nothing        
        for (name, encoder, offset) in encoders
            sub_names = get_scaler_names(encoder, parent_field_name=name)
            if parent_field_name != ""
                sub_names = ["$parent_field_name.$name" for name in sub_names]
            end
        end
    else 
        if parent_field_name != ""
            push!(names, parent_field_name)
        else 
            push!(names, this.name)
        end
    end

    return names
end


function get_decoder_output_field_types(this::AbstractEncoder) 
    flattened_field_type_list = this.flattened_field_type_list

    if flattened_field_type_list !== nothing
        return flattened_field_type_list
    end

    field_types = []

    encoders = this.encoders

    for (name, encoder, offset) in encoders
        sub_types = get_decoder_output_field_types(encoder)
        append!(encoders, sub_types)
    end

    this.flattened_field_type_list = field_types

    return field_types
end


function get_encoder_list(this::AbstractEncoder)
    flattened_encoder_list = this.flattened_encoder_list

    if flattened_encoder_list !== nothing
        return flattened_encoder_list
    end

    encoders = []

    encoders = this.encoders

    if encoders !== nothing
        for (name, encoder, offset) in encoders
            sub_encoders = get_encoder_list(encoder)
            append!(encoders, sub_encoders)
        end
    else
        push!(encoders, this)
    end

    this.flattened_encoder_list = encoders

    return encoders
end


function get_scalars(this::AbstractEncoder, input_data)
    encoders = this.encoders

    if encoders !== nothing
        ret_vals = []

        for (name, encoder, offset) in encoders
            values = get_scalars(encoder, input_data[name])
            ret_vals = hcat(ret_vals, values)
        end

        return ret_vals
    else
        return input_data
    end

end


function get_encoded_values(this::AbstractEncoder, input_data)
    ret_vals = []

    encoders = this.encoders

    if encoders !== nothing 
        for (name, encoder, offset) in encoders
            values = get_encoded_values(encoders, input_data[name])
            if values isa Dict
                push!(ret_vals, values)
            else 
                append!(ret_vals, values)
            end
        end
    else 
        if input_data isa Dict
            push!(ret_vals, input_data)
        else 
            append!(ret_vals, input_data)
        end
    end

    return ret_vals
end


function get_bucket_indices(this::AbstractEncoder, input_data)
    println("AbstractEncoder get_bucket_indices")
    ret_vals = []
    encoders = this.encoders
    if encoders !== nothing
        for (name, encoder, offset) in encoders
            values = get_bucket_indices(encoder, input_data[name])
            append!(ret_vals, values)
        end
    else
        error("get_bucket_indices should be implemented in base classes that are not containers for other encoders")
    end

    return ret_vals
end


function scalars_to_str(this::AbstractEncoder, scalar_values; scalar_names=nothing)
    if scalar_names === nothing
        scalar_names = get_scaler_names(this)
    end      

    desc = ""
    for (name, value) in zip(scalar_names, scalar_values)
        if length(desc) > 0
            desc *= @sprintf(", %s:%.2f", name, value)
        else
            desc *= @sprintf("%s:%.2f", name, value)
        end
    end

    return desc
end


function get_field_description(this::AbstractEncoder, field_name)
    descritpion = get_description(this);
    push!(descritpion, [("end", get_width(this))])

    (i, offset) = (() -> begin
        for i in 1:length(descritpion)
            (name, offset) = descritpion[i]
            if name == field_name
                return (i, offset)
            end
        end
        return (0, 0)
    end)()

    if i == 0
        error("Field name $field_name not found in this encoder")
    end

    return (offset, descritpion[i+1][2] - offset)
end


function encoded_bits_description(this::AbstractEncoder, bit_offset; formatted=false)
    (prev_field_name, prev_field_offset) = (nothing, nothing)
    description = get_description(this)
    for i in 1:length(description)
        (name, offset) = description[i]
        if formatted
            offset = offset + i
            if bit_offset == offset-1
                prev_field_name = "separator"
                prev_field_offset = bit_offset
                break
            end
        end
    end

    width = if formatted get_display_width(this) else get_width(this) end

    if prev_field_offset === nothing || bit_offset > get_width(this)
        error("Bit is outside of allowable range: [0 - $width]")
    end

    return (prev_field_name, bit_offset - prev_field_offset)
end


function pprint_header(this::AbstractEncoder; prefix="")
    print(prefix)
    description = get_description(this) 
    push!(description, [("end", get_width(this))])
    for i in 1:(length(description)-1)
        name = description[i][1]
        width = description[i+1][2] - description[i][2]
        format_str = @sprintf("%%-%ds |", width)
        if length(name) > width
            pname = name[1:width]
        else 
            pname = name
        end
        @eval @printf($format_str, $(pname))
    end
    print(" ")
    print("$prefix " * '-'^(get_width(this) + (length(description) - 1)*3 - 1))
end


function pprint(this::AbstractEncoder, output; prefix="")
    print(prefix)
    description = get_description(this)
    push!(description, [("end", get_width(this))])
    for i in 1:length(description)-1
        offset = description[i][2]
        nextoffset = description[i+1][2]
        print("$(bits_to_string(output[offset:nextoffset])) |")
    end
    print(" ")
end


function decode(this::AbstractEncoder, encoded::AbstractArray{<:Real}; parent_field_name="")
    fields_dict = Dict()
    fields_order = []

    if parent_field_name == ""
        parent_name = this.name
    else
        parent_name = "$parent_field_name.$(this.name)"
    end

    encoders = this.encoders

    if encoders !== nothing
        for i in 1:length(encoders)
            (name, encoder_, offset) = encoders[i]
            
            if i < length(encoders)
                next_offset = encoders[i+1][3]
            else
                next_offset = get_width(this)
            end

            field_output = view(encoded, offset:next_offset)
            (sub_fields_dict, sub_fields_order) = decode(encoder_, field_output; parent_field_name=parent_name)

            merge!(fields_dict, sub_fields_dict)
            append!(fields_order, sub_fields_order)
        end
    end

    return (fields_dict, fields_order)
end


function decoded_to_str(this::AbstractEncoder, decoded_results)
    (fields_dict, fields_order) = decoded_results

    desc = ""
    for field_name in fields_order
        (ranges, range_str) = fields_dict[field_name]
        if length(desc) > 0
            desc *= ", $field_name:"
        else
            desc *= " $field_name:"
        end

        desc *= "[$range_str]"
    end

    return desc
end


function get_bucket_info(this::AbstractEncoder, buckets)
    encoders = this.encoders
    if encoders === nothing
        error("Must be implemented in sub-class")
    end

    ret_vals = []
    bucket_offset = 1
    encoders = this.encoders
    for i in 1:length(encoders)
        (name, encoder, offset) = encoders[i]
        
        if encoder.encoders !== nothing
            next_bucket_offset = bucket_offset + length(encoder.encoders)
        else
            next_bucket_offset = bucket_offset + 1
        end

        bucket_indices = buckets[bucket_offset:next_bucket_offset-1]
        values = get_bucket_info(encoder, bucket_indices)

        append!(ret_vals, values)

        bucket_offset = next_bucket_offset
    end

    return ret_vals
end


function top_down_compute(this::AbstractEncoder, encoded)
    encoders = this.encoders
    if encoders === nothing
        error("Must be implemented in sub-class")
    end

    ret_vals = []
    encoders = this.encoders
    for i in 1:length(encoders)
        name, encoder, offset = encoders[i]

        if i < length(encoders)
            next_offset = encoders[i+1][3] 
        else
            next_offset = get_width(this) + 1
        end

        field_output = encoded[offset:next_offset - 1]
        values = top_down_compute(encoder, field_output)

        if values isa Dict
            push!(ret_vals, values)
        else
            append!(ret_vals, values)
        end
    end

    return ret_vals
end


function closeness_scores(this::AbstractEncoder, exp_values, act_values; fractional=true)
    encoders = this.encoders

    if encoders === nothing
        err = abs(exp_values[1] - act_values[1])
        if fractional
            denom = max(exp_values[1], act_values[1])
            if denom == 0
                denom = 1.0
            end
            closeness = 1.0 - err/denom
            if closeness < 0
                closeness = 0
            end
        else
            closeness = err
        end

        return [closeness]
    end

    scalar_idx = 1
    ret_vals = []
    for (name, encoder_, offset) in encoders
        values = closeness_scores(encoder_, exp_values[scalar_idx], act_values[scalar_idx], fractional=fractional)
        scalar_idx += length(values)
        ret_values = hcat(ret_vals, values)
    end

    return ret_vals
end


function get_display_width(this::AbstractEncoder)
    width = get_width(this) + length(get_description(this)) - 1
    return width
end


function bits_to_string(arr)
    s = repeat(['.'], length(arr))

    for i in 1:length(arr)
        if arr[i] == 1
            s[i] = '*'
        end
    end

    return string(s...)
end



include("scalar.jl")
include("adaptive_scalar.jl")
include("delta.jl")

include("category.jl")

include("date.jl")

include("coordinate.jl")
include("geospatial_coordinate.jl")

include("logarithm.jl")
include("multi.jl")

include("pass_through.jl")
include("sparse_pass_through.jl")

include("random_distribution_scalar.jl")
include("scalar_space.jl")
include("sdr_category.jl")