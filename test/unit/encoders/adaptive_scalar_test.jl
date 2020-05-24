@testset "AdaptiveScalarEncoderTest" begin
    
    @testset "test_missing_values" begin
        mv = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)
        empty = encode(mv, nothing)
        @test sum(empty) == 0
    end


    @testset "test_non_periodic_encoder_min_max_spec" begin
        l = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)
        @test encode(l, 1) == [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 2) == [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
        @test encode(l, 10) == [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]
    end


    @testset "test_top_down_decode" begin
        l = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)
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

            # Test bucket support
            bucket_indicies = get_bucket_indices(l, v)
            top_down = get_bucket_info(l, bucket_indicies)[1]
            @test abs(top_down.value - v) <= l.resolution/2
            @test top_down.value == get_bucket_values(l)[bucket_indicies[1]]
            @test top_down.scalar == top_down.value
            @test top_down.encoding == output

            v += l.resolution / 4
        end
    end


    @testset "test_fill_holes" begin
        l = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)
        decoded = decode(l, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1])
        field_dict, _ = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [10,10]

        decoded = decode(l, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1])
        field_dict, _ = decoded
        @test length(field_dict) == 1
        ranges = iterate(values(field_dict))[1][1]
        @test length(ranges) == 1
        @test ranges[1] == [10,10]
    end


    @testset "test_non_periodic_encoder_min_max_not_spec" begin
        l = AdaptiveScalarEncoder(5, nothing, nothing, 14; name="scalar", forced=true)

        function _verify(v, encoded, exp_v=nothing)
            if exp_v === nothing
                exp_v = v
            end

            @test encode(l, v) == encoded
            @test abs(get_bucket_info(l, get_bucket_indices(l, v))[1].value - exp_v) <= l.resolution/2
        end

        function _verify_not(v, encoded)
            @test encode(l, v) != encoded
        end

        _verify(1, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(2, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(10, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(3, [0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0])
        _verify(-9, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(-8, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(-7, [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(-6, [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(-5, [0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0])
        _verify(0, [0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0])
        _verify(8, [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0])
        _verify(8, [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0])
        _verify(10, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(11, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(12, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(13, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(14, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(15, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])

        l = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)

        _verify(1, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify(10, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(20, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(10, [0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0])

        l.learning_enabled = false
        _verify(30, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1], 20)
        _verify(20, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(-10, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0] ,1)
        _verify(-1, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1)

        l.learning_enabled = true
        _verify(30, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify_not(20, [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1])
        _verify(-10, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _verify_not(-1, [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end

    
    @testset "test_set_field_stats" begin
        _dump_params(enc) = (
            enc.n,
            enc.w,
            enc.minval,
            enc.maxval,
            enc.resolution,
            enc.learning_enabled,
            enc.record_num,
            enc.radius,
            enc.range_internal,
            enc.padding,
            enc.n_internal,
        )

        sfs = AdaptiveScalarEncoder(5, 1, 10, 14; name="scalar", forced=true)
        reg = AdaptiveScalarEncoder(5, 1, 100, 14; name="scalar", forced=true)

        @test _dump_params(sfs) != _dump_params(reg)

        set_field_stats!(sfs, "this", Dict("this"=>Dict("min"=>1, "max"=>100)))     
        
        @test _dump_params(sfs) == _dump_params(reg)
    end
end