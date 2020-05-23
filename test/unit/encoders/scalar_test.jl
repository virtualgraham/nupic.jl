@testset "ScalarEncoderTest" begin
    
    @testset "test_scalar_encoder" begin
        mv = ScalarEncoder(3, 1, 8; name="mv", n=14, periodic=false, forced=true)
        empty = encode(mv, nothing)
        @test sum(empty) == 0
    end


    @testset "test_nans" begin
        mv = ScalarEncoder(3, 1, 8; name="mv", n=14, periodic=false, forced=true)
        empty = encode(mv, NaN)
        @test sum(empty) == 0
    end


    @testset "test_bottom_up_encoding_periodic_encoder" begin
        l = ScalarEncoder(3, 1, 8;  n=14, periodic=true, forced=true)
        @test get_description(l) == [("[1:8]", 0)]
        
        l = ScalarEncoder(3, 1, 8; name="scalar", n=14, periodic=true, forced=true)
        @test get_description(l) == [("scalar", 0)]
        @test encode(l, 3) == [0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 3.1) == encode(l, 3)
        @test encode(l, 3.5) == [0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 3.6) == encode(l, 3.5)
        @test encode(l, 3.7) == encode(l, 3.5)
        @test encode(l, 4) == [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0]
        @test encode(l, 1) == [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        @test encode(l, 1.5) == [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 7) == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]
        @test encode(l, 7.5) == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1]
        @test l.resolution == 0.5
        @test l.radius == 1.5
    end


    @testset "test_create_resolution" begin
        l1 = ScalarEncoder(3, 1, 8; name="scalar", n=14, periodic=true, forced=true)
        l2 = ScalarEncoder(3, 1, 8; name="scalar", resolution=0.5, periodic=true, forced=true)
        l3 = ScalarEncoder(3, 1, 8; name="scalar", radius=1.5, periodic=true, forced=true)

        @test l1 == l2
        @test l2 == l3
    end


    @testset "test_decode_and_resolution" begin
        l = ScalarEncoder(3, 1, 8; name="scalar", n=14, periodic=true, forced=true)
        v = l.minval
        while v < l.maxval
            output = encode(l, v)
            decoded = decode(l, output)
            
            field_dict, field_names = decoded
            @test length(field_dict) == 1
            @test length(field_names) == 1
            @test collect(keys(field_dict)) == field_names
            ranges = iterate(values(field_dict))[1][1]
            @test length(ranges) == 1
            range_min, range_max = ranges[1]
            @test range_min == range_max
            @test abs(range_min - v) < l.resolution

            top_down = top_down_compute(l, output)[1]
            @test top_down.encoding ==  output
            @test abs(top_down.value - v) <= l.resolution / 2

            # Test bucket support
            bucket_indicies = get_bucket_indices(l, v)
            top_down = get_bucket_info(l, bucket_indicies)[1]
            @test abs(top_down.value - v) <= l.resolution/2
            @test top_down.value == get_bucket_values(l)[bucket_indicies[1]]
            @test top_down.scalar == top_down.value
            @test top_down.encoding == output

            v += l.resolution / 4
        end

        l = ScalarEncoder(3, 1, 8; name="scalar", radius=1.5, periodic=true, forced=true)

        # Test with a "hole"
        decoded = decode(l, [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0])
        field_dict, field_names = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [7.5, 7.5]

        # Test with something wider than w, and with a hole, and wrapped
        decoded = decode(l, [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0])
        field_dict, field_names = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 2
        @test ranges[1] == [7.5, 8]
        @test ranges[2] == [1, 1]

        # Test with something wider than w, no hole
        decoded = decode(l, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        field_dict, field_names = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [1.5, 2.5]

        # Test with 2 ranges
        decoded = decode(l, [1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0])
        field_dict, field_names = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 2
        @test ranges[1] == [1.5, 1.5]
        @test ranges[2] == [5.5, 6.0]

        # Test with 2 ranges, 1 of which is narrower than w
        decoded = decode(l, [0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0])
        field_dict, field_names = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 2
        @test ranges[1] == [1.5, 1.5]
        @test ranges[2] == [5.5, 6.0]
    end
    

    @testset "test_decode_and_resolution" begin
        encoder = ScalarEncoder(7, 0, 7; name="day of week", radius=1, periodic=true, forced=true)
        scores = closeness_scores(encoder, [2,4,7], [4,2,1]; fractional=false)
        for (actual, score) in zip([2,2,1], scores)
            @test actual == score
        end
    end


    @testset "test_non_periodic_bottom_up" begin
        l = ScalarEncoder(5, 1, 10; name="scalar", n=14, periodic=false, forced=true)
        @test encode(l, 1) == [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 2) == [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 10) == [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]

        l2 = ScalarEncoder(5, 1, 10; name="scalar", resolution=1, periodic=false, forced=true)
        @test l == l2

        l3 = ScalarEncoder(5, 1, 10; name="scalar", radius=5, periodic=false, forced=true)
        @test l == l3

        v = l.minval
        while v < l.maxval
            output = encode(l, v)
            decoded = decode(l, output)

            field_dict, _ = decoded
            @test length(field_dict) == 1
            ranges = iterate(values(field_dict))[1][1]
            @test length(ranges) == 1
            range_min, range_max = ranges[1]
            @test range_min == range_max
            @test abs(range_min - v) < l.resolution

            top_down = top_down_compute(l, output)[1]
            @test top_down.encoding ==  output
            @test abs(top_down.value - v) <= l.resolution

            # Test bucket support
            bucket_indicies = get_bucket_indices(l, v)
            top_down = get_bucket_info(l, bucket_indicies)[1]
            @test abs(top_down.value - v) <= l.resolution/2
            @test top_down.scalar == top_down.value
            @test top_down.encoding == output

            v += l.resolution / 4
        end

        # Make sure we can fill in holes
        decoded = decode(l, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1])
        field_dict, _ = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [10, 10]

        decoded = decode(l, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1])
        field_dict, _ = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [10, 10]

        #Test min and max
        l = ScalarEncoder(3, 1, 10; name="scalar", n=14, periodic=false, forced=true)
        decoded = top_down_compute(l, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1])[1]
        @test decoded.value == 10
        decoded = top_down_compute(l, [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])[1]
        @test decoded.value == 1

        #Make sure only the last and first encoding encodes to max and min, and
        #there is no value greater than max or min
        l = ScalarEncoder(3, 1, 141; name="scalar", n=140, periodic=false, forced=true)
        for i in 1:138
            npar = zeros(140)
            for j in i:i+2
                npar[j] = 1
            end
            decoded = top_down_compute(l, npar)[1]
            @test decoded.value <= 141
            @test decoded.value >= 1
            @test decoded.value < 141 || i == 138
            @test decoded.value > 1 || i == 1
        end

        # Test the input description generation and top-down compute on a small
        # number non-periodic encoder
        l = ScalarEncoder(3, .001, .002; name="scalar", n=15, periodic=false, forced=true)
        v = l.minval
        while v < l.maxval
            output = encode(l, v)
            decoded = decode(l, output)

            field_dict, _ = decoded
            @test length(field_dict) == 1
            ranges = iterate(values(field_dict))[1][1]
            @test length(ranges) == 1
            range_min, range_max = ranges[1]
            @test range_min == range_max
            @test abs(range_min - v) < l.resolution

            top_down = top_down_compute(l, output)[1]
            @test abs(top_down.value - v) <= l.resolution / 2

            v += l.resolution / 4
        end
    end


    @testset "test_encode_invalid_input_type" begin
        encoder = ScalarEncoder(3, 1, 8; name="enc", n=14, periodic=false, forced=true)
        @test_throws MethodError encode(encoder, "String")
    end


    @testset "test_get_bucket_info_int_resolution" begin
        encoder = ScalarEncoder(3, 1, 8; resolution=1, periodic=true, forced=true)
        @test 4.5 == top_down_compute(encoder, encode(encoder, 4.5))[1].scalar
    end


    @testset "test_read_write" begin
        #TODO: Implement
    end


    @testset "test_setting_n_with_maxval_minval_none" begin
        encoder = ScalarEncoder(3, nothing, nothing; name="scalar", n=14, radius=0, resolution=0, forced=true)
        @test isa(encoder, ScalarEncoder)
    end


    @testset "test_setting_scalar_and_resolution" begin
        @test_throws ErrorException ScalarEncoder(3, nothing, nothing; name="scalar", n=0, radius=nothing, resolution=0.5, forced=true)
    end


    @testset "test_setting_radius_with_maxval_minavl_none" begin
        encoder = ScalarEncoder(3, nothing, nothing; name="scalar", n=0, radius=1.5, resolution=0, forced=true)
        @test isa(encoder, ScalarEncoder)
    end

end