using Printf

abstract type Encoder end


function get_encoders(encoder::Encoder)
    error("Encoder method get_encoders not implemented")
end


function get_name(encoder::Encoder)
    error("Encoder method get_name not implemented")
end


function get_flattened_field_type_list(encoder::Encoder)
    return
end


function set_flattened_field_type_list(encoder::Encoder, field_types)
    return
end


function get_flattened_encoder_list(encoder::Encoder)
    return
end


function set_flattened_encoder_list(encoder::Encoder, encoders)
    return
end


function get_width(encoder::Encoder)
    error("Encoder method get_width not implemented")
end


function encode_into_array(encoder::Encoder, input_data, output::BitArray; learn=true)
    error("Encoder method encode_into_array not implemented")
end


function set_learning(encoder::Encoder, learning_enabled::Bool)
    return
end


function set_field_stats(encoder::Encoder)
    return
end


function encode(encoder::Encoder, input_data)
    output = BitArray(undef, get_width(encoder))
    encode_into_array(encoder, input_data, output)
    return output
end


function get_scaler_names(encoder::Encoder; parent_field_name="") 
    names = String[]

    encoders = get_encoders(encoder)

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
            push!(names, get_name(encoder))
        end
    end

    return names
end


function get_decoder_output_field_types(encoder::Encoder) 
    flattened_field_type_list = get_flattened_field_type_list(encoder)

    if flattened_field_type_list !== nothing
        return flattened_field_type_list
    end

    field_types = []

    encoders = get_encoders(encoder)

    for (name, encoder, offset) in encoders
        sub_types = get_decoder_output_field_types(encoder)
        append!(encoders, sub_types)
    end

    set_flattened_field_type_list(encoder, field_types)

    return field_types
end


function set_state_lock(encoder::Encoder, lock)
    return
end


# function get_input_value(encoder::Encoder, obj::Dict, field_name)
    # input_data should strictly be a Dict so there is no need to disambiguate
# end


function get_encoder_list(encoder::Encoder)
    flattened_encoder_list = get_flattened_encoder_list(encoder)

    if flattened_encoder_list !== nothing
        return flattened_encoder_list
    end

    encoders = []

    encoders = get_encoders(encoder)

    if encoders !== nothing
        for (name, encoder, offset) in encoders
            sub_encoders = get_encoder_list(encoder)
            append!(encoders, sub_encoders)
        end
    else
        push!(encoders, encoder)
    end

    set_flattened_encoder_list(encoder, encoders)

    return encoders
end


function get_scalars(encoder::Encoder, input_data)
    encoders = get_encoders(encoder)

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


function get_encoded_values(encoder::Encoder, input_data)
    ret_vals = []

    encoders = get_encoders(encoder)

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


function get_bucket_indices(encoder::Encoder, input_data)
    ret_vals = []
    encoders = get_encoders(encoder)
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


function scalars_to_str(encoder::Encoder, scalar_values; scalar_names=nothing)
    if scalar_names === nothing
        scalar_names = get_scaler_names(encoder)
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


function get_description(encoder::Encoder)
    error("getDescription must be implemented by all subclasses")
end


function get_field_description(encoder::Encoder, field_name)
    descritpion = get_description(encoder);
    push!(descritpion, [("end", get_width(encoder))])

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


function encoded_bits_description(encoder::Encoder, bit_offset; formatted=false)
    (prev_field_name, prev_field_offset) = (nothing, nothing)
    description = get_description(encoder)
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

    width = if formatted get_display_width(encoder) else get_width(encoder) end

    if prev_field_offset === nothing || bit_offset > get_width(encoder)
        error("Bit is outside of allowable range: [0 - $width]")
    end

    return (prev_field_name, bit_offset - prev_field_offset)
end


function pprint_header(encoder::Encoder; prefix="")
    print(prefix)
    description = get_description(encoder) 
    push!(description, [("end", get_width(encoder))])
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
    print("$prefix " * '-'^(get_width(encoder) + (length(description) - 1)*3 - 1))
end


function pprint(encoder::Encoder, output; prefix="")
    print(prefix)
    description = get_description(encoder)
    push!(description, [("end", get_width(encoder))])
    for i in 1:length(description)-1
        offset = description[i][2]
        nextoffset = description[i+1][2]
        print("$(bits_to_string(output[offset:nextoffset])) |")
    end
    print(" ")
end


function decode(encoder::Encoder, encoded; parent_field_name="")
    fields_dict = Dict()
    fields_order = []

    if parent_field_name == ""
        parent_name = get_name(encoder)
    else
        parent_name = "$parent_field_name.$(get_name(encoder))"
    end

    encoders = get_encoders(encoder)

    if encoders !== nothing
        for i in 1:length(encoders)
            (name, encoder, offset) = encoders[i]
            if i < length(encoders)
                next_offset = encoders[i+1][3]
            else
                next_offset = get_width(encoder)
            end
            field_output = encoded[offset:next_offset]
            (sub_fields_dict, sub_fields_order) = decode(encoder, field_output; parent_field_name=parent_name)

            merge!(fields_dict, sub_fields_dict)
            append!(fields_order, sub_fields_order)
        end
    end

    return (fields_dict, fields_order)
end


function decoded_to_str(encoder::Encoder, decoded_results)
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


function get_bucket_values(encoder::Encoder, decoded_results)
    error("getBucketValues must be implemented by all subclasses")
end


function get_bucket_info(encoder::Encoder, buckets)
    encoders = get_encoders(encoder)
    if encoders === nothing()
        error("Must be implemented in sub-class")
    end

    ret_vals = []
    bucket_offset = 0
    encoders = get_encoders(encoder)
    for i in 1:length(encoders)
        (name, encoder, offset) = encoders[i]
        
        if encoders !== nothing
            next_bucket_offset = bucket_offset + length(encoders)
        else
            next_bucket_offset = bucket_offset + 1
        end

        bucket_indices = buckets[bucket_offset:next_bucket_offset]
        values = get_bucket_info(encoder, bucket_indices)

        append!(ret_vals, values)

        bucket_offset = next_bucket_offset
    end

    return ret_vals
end


function top_down_compute(encoder::Encoder, encoded)
    encoders = get_encoders(encoder)
    if encoders === nothing()
        error("Must be implemented in sub-class")
    end

    ret_vals = []
    encoders = get_encoders(encoder)
    for i in 1:length(encoders)
        (name, encoder, offset) = encoders[i]

        if i < length(encoders) - 1
            next_offset = encoders[i+1][3]
        else
            next_offset = get_width(encoder)
        end

        field_output = encoded[offset:next_offset]
        values = top_down_compute(encoder, field_output)

        if values isa Dict
            push!(ret_vals, values)
        else
            append!(ret_vals, values)
        end
    end

    return ret_vals
end


function closeness_scores(encoder::Encoder, exp_values, act_values; fractional=true)
    encoders = get_encoders(encoder)

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
    for (name, encoder, offset) in encoders
        values = closeness_scores(encoder, exp_values[scalar_idx], act_values[scalar_idx], fractional=fractional)
        scalar_idx += length(values)
        ret_values = hcat(ret_vals, values)
    end

    return ret_vals
end


function get_display_width(encoder::Encoder)
    width = get_width(encoder) + length(get_description(encoder)) - 1
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

