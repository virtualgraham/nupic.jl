abstract type Encoder end

InputData = Union{Dict,Vector}

# interface method, implement in subtype
function get_width(encoder::Encoder)
    error("Encoder method get_width not implemented")
end


# interface method, implement in subtype
function encode_into_array(encoder::Encoder, input_data::InputData, output::Array{Int8})
    error("Encoder method encode_into_array not implemented")
end


# interface method, implement in subtype
function set_learning(encoder::Encoder, learning_enabled::Bool)
    return
end


# interface method, implement in subtype
function set_field_stats(encoder::Encoder)
    return
end


function encode(encoder::Encoder, input_data::InputData)
    output = zeros(UInt8, get_width(encoder))
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
            push!(names, encoder.get_name())
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

# todo: refactor to only accept Dict input_data
function get_scalars(encoder::Encoder, input_data::InputData)
    
    encoders = get_encoders(encoder)

    if encoders !== nothing
        # input data should always be a dict in this case
        ret_vals = []

        for (name, encoder, offset) in encoders
            values = get_scalars(encoder, input_data[name])
            ret_vals = hcat(ret_vals, values)
        end

        return ret_vals
    else
        # input data should always be an array in this case
        # ret_vals = hcat(ret_vals, input_data) 
        return input_data
    end

end


function get_encoded_values(encoder::Encoder, input_data::InputData)
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


function get_bucket_indices(encoder::Encoder, input_data::InputData)
    # TODO: implement
end


function scalars_to_Str(encoder::Encoder, scalar_values; scalar_names=nothing)
    # TODO: implement
end


# interface method, implement in subtype
function get_description(encoder::Encoder)
    error("Encoder method get_description not implemented")
end


function get_field_description(encoder::Encoder, field_name)
    # TODO: implement
end


function encoded_bits_description(encoder::Encoder, bit_offset; formatted=false)
    # TODO: implement
end


function pprint_header(encoder::Encoder; prefix="")
    # TODO: implement
end


function pprint(encoder::Encoder, output; prefix="")
    # TODO: implement
end


function decode(encoder::Encoder, encoded; parent_field_name="")
    # TODO: implement
end


function decoded_to_str(encoder::Encoder, decoded_results)
    # TODO: implement
end


function get_bucket_values(encoder::Encoder, decoded_results)
    # TODO: implement
end


function get_bucket_info(encoder::Encoder, buckets)
    # TODO: implement
end


function top_down_compute(encoder::Encoder, encoded)
    # TODO: implement
end


function closeness_scores(encoder::Encoder, exp_values, act_values; fractional=true)
    # TODO: implement
end


function get_display_width(encoder::Encoder)
    width = get_width(encoder) + length(get_description(encoder)) - 1
    return width
end



# interface method, implement in subtype
# returns an array of tuples (name, encoder, offset)
function get_encoders(encoder::Encoder)
    error("Encoder method get_encoders not implemented")
end

# interface method, implement in subtype
function get_name(encoder::Encoder)
    error("Encoder method get_name not implemented")
end


# interface method, implement in subtype
function get_flattened_field_type_list(encoder::Encoder)
    return
end

# interface method, implement in subtype
function set_flattened_field_type_list(encoder::Encoder, field_types)
    return
end

# interface method, implement in subtype
function get_flattened_encoder_list(encoder::Encoder)
    return
end

# interface method, implement in subtype
function set_flattened_encoder_list(encoder::Encoder, encoders)
    return
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

