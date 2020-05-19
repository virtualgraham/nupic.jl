using Printf
import Base.show

abstract type AbstractScalarEncoder <: Encoder end

const DEFAULT_RESOLUTION = 0
const DEFAULT_RADIUS = 0

"""
A scalar encoder encodes a numeric (floating point) value into an array
of bits. The output is 0's except for a contiguous block of 1's. The
location of this contiguous block varies continuously with the input value.

The encoding is linear. If you want a nonlinear encoding, just transform
the scalar (e.g. by applying a logarithm function) before encoding.
It is not recommended to bin the data as a pre-processing step, e.g.
"1" = $0 - $.20, "2" = $.21-$0.80, "3" = $.81-$1.20, etc. as this
removes a lot of information and prevents nearby values from overlapping
in the output. Instead, use a continuous transformation that scales
the data (a piecewise transformation is fine).

.. warning:: There are three mutually exclusive parameters that determine the
   overall size of of the output. Exactly one of n, radius, resolution must be
   set. "0" is a special value that means "not set".

:param w: The number of bits that are set to encode a single value - the
          "width" of the output signal restriction: w must be odd to avoid
          centering problems.

:param minval: The minimum value of the input signal.

:param maxval: The upper bound of the input signal. (input is strictly less if
            ``periodic == True``)

:param periodic: If true, then the input value "wraps around" such that
            ``minval`` = ``maxval``. For a periodic value, the input must be
            strictly less than ``maxval``, otherwise ``maxval`` is a true
            upper bound.

:param n: The number of bits in the output. Must be greater than or equal to
          ``w``

:param radius: Two inputs separated by more than the radius have
               non-overlapping representations. Two inputs separated by less
               than the radius will in general overlap in at least some of
               their bits. You can think of this as the radius of the input.

:param resolution: Two inputs separated by greater than, or equal to the
                   resolution are guaranteed to have different
                   representations.

:param name: an optional string which will become part of the description

:param clipInput: if true, non-periodic inputs smaller than minval or greater
          than maxval will be clipped to minval/maxval

:param forced: if true, skip some safety checks (for compatibility reasons),
               default false

.. note:: ``radius`` and ``resolution`` are specified with respect to the
   input, not output. ``w`` is specified with respect to the output.

**Example: day of week**

.. code-block:: text

   w = 3
   Minval = 1 (Monday)
   Maxval = 8 (Monday)
   periodic = true
   n = 14
   [equivalently: radius = 1.5 or resolution = 0.5]

The following values would encode midnight -- the start of the day

.. code-block:: text

   monday (1)   -> 11000000000001
   tuesday(2)   -> 01110000000000
   wednesday(3) -> 00011100000000
   ...
   sunday (7)   -> 10000000000011

Since the resolution is 12 hours, we can also encode noon, as

.. code-block:: text

   monday noon  -> 11100000000000
   monday midnt-> 01110000000000
   tuesday noon -> 00111000000000
   etc.

**`n` vs `resolution`**

It may not be natural to specify "n", especially with non-periodic
data. For example, consider encoding an input with a range of 1-10
(inclusive) using an output width of 5.  If you specify resolution =
1, this means that inputs of 1 and 2 have different outputs, though
they overlap, but 1 and 1.5 might not have different outputs.
This leads to a 14-bit representation like this:

.. code-block:: text

   1 ->  11111000000000  (14 bits total)
   2 ->  01111100000000
   ...
   10->  00000000011111
   [resolution = 1; n=14; radius = 5]

You could specify resolution = 0.5, which gives

.. code-block:: text

   1   -> 11111000... (22 bits total)
   1.5 -> 011111.....
   2.0 -> 0011111....
   [resolution = 0.5; n=22; radius=2.5]

You could specify radius = 1, which gives

.. code-block:: text

   1   -> 111110000000....  (50 bits total)
   2   -> 000001111100....
   3   -> 000000000011111...
   ...
   10  ->                           .....000011111
   [radius = 1; resolution = 0.2; n=50]

An N/M encoding can also be used to encode a binary value,
where we want more than one bit to represent each state.
For example, we could have: w = 5, minval = 0, maxval = 1,
radius = 1 (which is equivalent to n=10)

.. code-block:: text

   0 -> 1111100000
   1 -> 0000011111


**Implementation details**

.. code-block:: text

   range = maxval - minval
   h = (w-1)/2  (half-width)
   resolution = radius / w
   n = w * range/radius (periodic)
   n = w * range/radius + 2 * h (non-periodic)

"""
mutable struct ScalarEncoder <: AbstractScalarEncoder

    w::Integer
    minval::Union{Float64, Nothing}
    maxval::Union{Float64, Nothing}
    periodic::Bool
    n
    radius
    resolution
    name::String
    verbosity
    clip_input::Bool

    encoders
    halfwidth
    range
    range_internal::Float64
    n_internal
    _top_down_mapping_m
    _top_down_values
    _bucket_values
    padding

    function ScalarEncoder(
        w::Integer,
        minval::Union{Float64, Nothing},
        maxval::Union{Float64, Nothing};
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
        halfwidth = (w-1)/2
        range = 0
        range_internal = 0
       
        # This matrix is used for the topDownCompute. We build it the first time
        #  topDownCompute is called
        _top_down_mapping_m = nothing
        _top_down_values = nothing

        # This list is created by getBucketValues() the first time it is called,
        #  and re-created whenever our buckets would be re-arranged.
        _bucket_values = nothing

        # For non-periodic inputs, padding is the number of bits "outside" the range,
        # on each side. I.e. the representation of minval is centered on some bit, and
        # there are "padding" bits to the left of that centered bit; similarly with
        # bits to the right of the center bit of maxval
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

        # There are three different ways of thinking about the representation. Handle
        # each case here.
        if n != 0
            if radius != 0 || resolution != 0
                error("Only one of n/radius/resolution can be specified for a ScalarEncoder")
            end
            @assert( n > w )

            if minval !== nothing && maxval != nothing
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

            if minval !== nothing & maxval !== nothing
                if periodic
                    range = range_internal
                else
                    range = range_internal + resolution
                end

                nfloat = w * (range / radius) + 2 * padding
                n = ceil(nfloat)
            end
        end

        # nInternal represents the output area excluding the possible padding on each
        #  side
        if minval !== nothing && maxval !== nothing
            n_internal = n - 2 * padding
        end

        # Our name
        if name === nothing
            name = "[$minval:$maxval]"
        end

        # checks for likely mistakes in encoder settings
        if !forced 
             # check reasonable settings
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
            padding
        )
    end
end

function get_decoder_output_field_types(encoder::ScalarEncoder)
    (Float64,)
end

function get_width(encoder::ScalarEncoder)
    encoder.n
end

function recalc_params!(encoder::ScalarEncoder)
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


function get_description(encoder::ScalarEncoder)
    [(encoder.name, 0)]
end

""" 
Return the bit offset of the first bit to be set in the encoder output.
For periodic encoders, this can be a negative number when the encoded output
wraps around. 
"""
function get_first_on_bit(encoder::ScalarEncoder, input::Union{Nothing, Float64})
    if input === nothing
        return nothing
    else

        if input < encoder.minval
             # Don't clip periodic inputs. Out-of-range input is always an error
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
             # Don't clip periodic inputs. Out-of-range input is always an error
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

        if encoder.periodic
            centerbin = ((input - encoder.minval) * encoder.n_internal / encoder.range) + encoder.padding
        else
            centerbin = (((input - encoder.minval) * encoder.resolution/2) / encoder.resolution) + encoder.padding
        end

        # We use the first bit to be set in the encoded output as the bucket index
        minbin = centerbin - encoder.halfwidth;
        return minbin
    end
end

""" 
See method description in base.jl 
"""
function get_bucket_indices(encoder::ScalarEncoder, input::Union{Nothing, Float64})
    if input === nothing || isnan(input) return [nothing] end
    
    minbin = get_first_on_bit(encoder, input)

    if encoder.periodic
        bucket_idx = minbin + encoder.halfwidth
        if bucket_idx < 0 bucket_idx += encoder.n end
    else
        bucket_idx = minbin
    end

    return [bucket_idx]
end

""" 
See method description in base.py 
"""
function encode_into_array(encoder::ScalarEncoder, input::Union{nothing, Float64}, output::Array{Float64}; learn=true)
    if input !== nothing && isnan(input) 
        input = nothing 
    end

    bucket_idx = get_first_on_bit(encoder, input)

    if bucket_idx === nothing
        output[1:encoder.n] .= 0
    else
        output[1:encoder.n] .= 0
        minbin = bucket_idx
        maxbin = minbin + 2*encoder.halfwidth
        if encoder
            if maxbin >= encoder.n
                bottombins = maxbin - encoder.n + 1
                output[1:bottombins] .= 1
                maxbin = encoder.n - 1
            end 
            if minbin < 0
                topbins = -minbin
                output[(encoder.n - topbins + 1):encoder.n] .= 1
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

""" 
See the function description in base.py
"""
function decode(encoder::ScalarEncoder, encoded::Vector{Float64}; parent_field_name='')
    
    # For now, we simply assume any top-down output greater than 0
    #  is ON. Eventually, we will probably want to incorporate the strength
    #  of each top-down output.
    tmp_output = Vector{Float64}( encoded .<= 0 )
    if !any(x->x>0, tmp_output)
            return (Dict(), [])
    end

    # ------------------------------------------------------------------------
    # First, assume the input pool is not sampled 100%, and fill in the
    #  "holes" in the encoded representation (which are likely to be present
    #  if this is a coincidence that was learned by the SP).

    # Search for portions of the output that have "holes"
    max_zeros_in_a_row = encoder.halfwidth
    for i in 1:max_zeros_in_a_row 
        search_str = ones(i + 2)
        search_str[2:i + 1] .= 0
        sub_len = length(search_str)

        # Does this search string appear in the output?
        if encoder.periodic
            for j in 1:encoder.n
                output_indices = collect(j-1:j+sub_len-2)
                output_indices .%= encoder.n
                output_indices .+= 1
                if search_str == tmp_output[output_indices]
                    tmp_output[output_indices] .= 1
                end
            end
        else
            for j in 1:(encoder.n - sub_len + 1)
                if search_str == tmp_output[j:(j + sub_len)]
                    tmp_output[j:j + sub_len] .= 1
                end
            end
        end
    end

    if encoder.verbosity >= 2
        println(
            """
            raw output: $(encoded[1:encoded.n])
            filtered output: $tmp_output
            """
        )
    end

    # ------------------------------------------------------------------------
    # Find each run of 1's.
    nz = findall(x->x>0, tmp_output) 
    runs = []
    run = [nz[1], 1]
    i = 2
    while i < length(nz)
        if nz[i] == run[1] + run[2]
            run[2] += 1
        else 
            runs.push(run)
            run = [nz[i], 1]
        end
        i += 1
    end
    runs.push(run)

    # If we have a periodic encoder, merge the first and last run if they
    #  both go all the way to the edges
    if encoder.periodic && length(runs) > 1
        if runs[1][1] == 0 && runs[lastindex(runs)][1] + runs[lastindex(runs)][2] == encoder.n
            runs[lastindex(runs)][2] += runs[1][2]
            runs = runs[2:lastindex(runs)]
        end
    end

    # ------------------------------------------------------------------------
    # Now, for each group of 1's, determine the "left" and "right" edges, where
    #  the "left" edge is inset by halfwidth and the "right" edge is inset by
    #  halfwidth.
    # For a group of width w or less, the "left" and "right" edge are both at
    #   the center position of the group.
    ranges = []
    for run in runs
        (start, run_len) = run
        if run_len < encoder.w
            left = right = start + run_len/2
        else
            left = start + encoder.halfwidth
            right = start + run_len - 1 - encoder.halfwidth
        end

        # Convert to input space.
        if !encoder.periodic
            in_min = (left - encoder.padding) * encoder.resolution + encoder.minval
            in_max = (right - encoder.padding) * encoder.resolution + encoder.minval
        else
            in_min = (left - encoder.padding) * encoder.range / encoder.n_internal + encoder.minval
            in_max = (right - encoder.padding) * encoder.range / encoder.n_internal + encoder.minval
        end
        # Handle wrap-around if periodic
        if encoder.periodic
            if in_min >= encoder.maxval
                in_min -= encoder.range
                in_max -= encoder.range
            end
        end

        # Clip low end
        if in_min < encoder.minval
            in_min = encoder.minval
        end
        if in_max < encoder.minval
            in_max = encoder.minval
        end

        # If we have a periodic encoder, and the max is past the edge, break into
        #  2 separate ranges
        if encoder.periodic && in_max >= encoder.maxval
            push!(ranges, [in_min, encoder.maxval])
            push!(ranges, [encoder.minval, in_max = encoder.range])
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

    desc = generate_range_description(encoder, ranges)
    # Return result
    if parent_field_name != ""
        field_name = "$parent_field_name.$(encoder.name)"
    else
        field_name = encoder.name
    end

    return (Dict(field_name => (ranges, desc)), [field_name])
end

"""
generate description from a text description of the ranges
"""
function generate_range_description(encoder::ScalarEncoder, ranges)
    desc = ""
    num_ranges = length(ranges)
    for i in 1:num_ranges
        if ranges[i][1] != ranges[i][2]
            desc *= @sprintf("%.2f-%.2f", ranges[i][1], ranges[i][2])
        else
            desc *= @sprintf("%.2f", ranges[i][1])
        end
        if i < num_ranges - 1
            desc *= ","
        end
    end
    return desc
end

""" 
Return the interal _topDownMappingM matrix used for handling the
bucketInfo() and topDownCompute() methods. This is a matrix, one row per
category (bucket) where each row contains the encoded output for that
category.
"""
function get_top_down_mapping(encoder::ScalarEncoder)

end

""" 
See the function description in base.py
"""
function get_bucket_values(encoder::ScalarEncoder)

end

""" 
See the function description in base.py 
"""
function get_bucket_info(encoder::ScalarEncoder, buckets)

end

""" 
See the function description in base.py
"""
function top_down_compute(encoder::ScalarEncoder, encoded)

end

""" 
See the function description in base.py
"""
function closeness_scores(encoder::ScalarEncoder, exp_values, act_values; fractional=true)

end


function Base.show(io::IO, encoder::ScalarEncoder)
    string = 
    println(
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