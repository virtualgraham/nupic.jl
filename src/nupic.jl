module NuPIC

include("utils.jl")
include("object.jl")
include("encoders/base.jl")

# encoders
export Encoder, ScalarEncoder, AdaptiveScalarEncoder, DeltaEncoder

export get_width, encode_into_array, encode, get_scaler_names, 
    get_decoder_output_field_types, get_encoder_list, get_scalars, get_encoded_values, 
    get_bucket_indices, scalars_to_str, get_description, get_field_description, 
    encoded_bits_description, pprint_header, pprint, decode, decoded_to_str, 
    get_bucket_values, get_bucket_info, top_down_compute, closeness_scores, 
    get_display_width, set_field_stats!

end # module