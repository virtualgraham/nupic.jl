
abstract type Encoder end


# interface method, implement in subtype
function get_width(encoder::Encoder)
    error("Encoder method get_width not implemented")
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
function encode_into_array(encoder::Encoder, input_data, output::Array{Int8})
    error("Encoder method encode_into_array not implemented")
end

# interface method, implement in subtype
function get_flattened_field_type_list(encoder::Encoder)
    return
end

# interface method, implement in subtype
function set_learning(encoder::Encoder, learning_enabled::Bool)
    return
end

# interface method, implement in subtype
function set_field_stats(encoder::Encoder)
    return
end


function encode(encoder::Encoder, input_data)
    output = zeros(UInt8, get_width(encoder))
    encode_into_array(encoder, input_data, output)
    return output
end


function get_scaler_names(encoder:Encoder; parent_field_name="") 
    names = String[]

    encoders = encoder.get_encoders()

    if encoders != Nothing 
        for (name, encoder, offset) in encoders
            sub_names = get_scaler_names(encoder, parent_field_name=name)
            if parent_field_name != ""
                sub_names = ["$parent_field_name.$name" for name in sub_names]
            end
        end
    else 
        if parent_field_name != ""
            names.push!(parent_field_name)
        else 
            names.push!(encoder.get_name())
        end
    end

    return names
end



