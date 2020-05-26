abstract type AbstractCategoryEncoder <: Encoder end

const UNKNOWN = "<UNKNOWN>"
const MISSING = "<missing>"

mutable struct CategoryEncoder <: AbstractCategoryEncoder
    encoders
    verbosity::Integer
    ncategories::Integer
    category_to_index
    index_to_category
    encoder::ScalarEncoder
    width::Integer
    description
    name::String
    _top_down_mapping_m
    _bucket_values
    flattened_field_type_list
    flattened_encoder_list

    function CategoryEncoder(
        w,
        category_list::Vector{String};
        name="category",
        verbosity=0,
        forced=false
    )

        encoders = nothing
        ncategories = length(category_list) + 1
        category_to_index = Dict()
        index_to_category = Dict(1 => UNKNOWN)
        for i in 1:length(category_list)
            category_to_index[category_list[i]] = i+1
            index_to_category[i+1] = category_list[i]
        end
        encoder = ScalarEncoder(w, 1, ncategories; radius=1, periodic=false, forced=forced)
        width = w * ncategories
        @assert get_width(encoder) == width
        description = [(name, 0)]
            
        return new(
            encoders,
            verbosity,
            ncategories,
            category_to_index,
            index_to_category,
            encoder,
            width,
            description,
            name,
            nothing,
            nothing,
            nothing,
            nothing
        )
    end
end


get_decoder_output_field_types(encoder::AbstractCategoryEncoder) = (Integer,)
get_width(encoder::AbstractCategoryEncoder) = encoder.width
get_description(encoder::AbstractCategoryEncoder) = encoder.description


function get_scalars(encoder::AbstractCategoryEncoder, input)
    if input === nothing
        return [nothing]
    else
        return get(encoder.category_to_index, input, 1)
    end
end


function get_bucket_indices(encoder::AbstractCategoryEncoder, input; learn=nothing)
    if input === nothing
        return [nothing]
    else
        return get_bucket_indices(encoder.encoder, get(encoder.category_to_index, input, 1))
    end
end


function encode_into_array(encoder::AbstractCategoryEncoder, input, output::BitArray; learn=nothing)
    if input === nothing
        output[1,:] = 0
        val = MISSING
    else
        println("input $input encoder.category_to_index $(encoder.category_to_index)")
        val = get(encoder.category_to_index, input, 1)
        encode_into_array(encoder.encoder, val, output)
    end

    if encoder.verbosity >= 2
        println("input: $input val: $val output $output")
        println("decoded: $(decoded_to_str(encoder, decode(encoder, output)))")
    end
end


function decode(encoder::AbstractCategoryEncoder, encoded::Union{Vector{Int64}, Vector{Float64}}; parent_field_name="")
    fields_dict, field_names = decode(encoder.encoder, encoded)
    if length(fields_dict) == 0
        return fields_dict, field_names
    end

    @assert length(fields_dict) == 1

    in_ranges, indesc = iterate(values(fields_dict))
    out_ranges = []
    desc = ""
    for (min_v, max_v) in in_ranges
        min_v = Integer(round(min_v))
        max_v = Integer(round(max_v))
        push!(out_ranges, (min_v, max_v))
        while min_v < max_v
            if length(desc) > 0
                desc *= ", "
            end
            desc *= encoder.index_to_category[min_v]
            min_v += 1
        end

        if parent_field_name != ""
            field_name = "$parent_field_name.$(encoder.name)"
        else
            field_name = encoder.name
        end
        return (Dict(field_name=>(out_ranges, desc)), [field_name])
    end
end


function closeness_scores(encoder::AbstractCategoryEncoder, exp_values, act_values; fractional=true)
    exp_value = exp_values[1]
    act_value = act_values[1]

    if exp_value == act_value
        closeness = 1.0
    else 
        closeness = 0.0
    end

    if !fractional
        closeness = 1.0 - closeness
    end

    return [closeness]
end


function get_bucket_values(encoder::AbstractCategoryEncoder)
    if encoder._bucket_values === nothing
        num_buckets = length(get_bucket_values(encoder.encoder))
        encoder._bucket_values = []
        for bucket_index in 1:num_buckets
            push!(encoder._bucket_values, get_bucket_info(encoder, [bucket_index])[1].value)
        end
    end
    
    return encoder._bucket_values
end


function get_bucket_info(encoder::AbstractCategoryEncoder, buckets)
    bucket_info = get_bucket_info(encoder.encoder, buckets)[1]

    category_index = Integer(round(bucket_info.value))
    category = encoder.index_to_category[category_index]

    return [(value=category, scalar=category_index, encoding=bucket_info.encoding)]
end


function top_down_compute(encoder::AbstractCategoryEncoder, encoded)
    encoder_result = top_down_compute(encoder.encoder, encoded)[1]
    value = encoder_result.value
    category_index = Integer(round(value))
    category = encoder.index_to_category[category_index]

    return (value=category, scalar=category_index, encoding=encoder_result.encoding)
end
