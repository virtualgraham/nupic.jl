@testset "DeltaEncoderTest" begin
    
    @testset "test_delta_encoder" begin
        adaptscalar = AdaptiveScalarEncoder(21, nothing, nothing, 100; forced=true)
        dencoder = DeltaEncoder(21, nothing, nothing, 100; forced=true)

        encarr = nothing

        for i in 0:4
            encarr = BitArray(undef, 100)
            encode_into_array(dencoder, i, encarr; learn=true)
        end
        dencoder.state_lock = true
        for i in 5:6
            encarr = BitArray(undef, 100)
            encode_into_array(dencoder, i, encarr; learn=true)
        end
        res = top_down_compute(dencoder, encarr)
        @test res[1].value == 6
        @test top_down_compute(dencoder, encarr)[1].value == res[1].value
        @test top_down_compute(dencoder, encarr)[1].scalar == res[1].scalar
        @test top_down_compute(dencoder, encarr)[1].encoding == res[1].encoding
    end


    @testset "test_encoding_verification" begin
        adaptscalar = AdaptiveScalarEncoder(21, nothing, nothing, 100; forced=true)
        dencoder = DeltaEncoder(21, nothing, nothing, 100; forced=true)

        feed_in = [1, 10, 4, 7, 9, 6, 3, 1]
        expected_out = [0, 9, -6, 3, 2, -3, -3, -2]
        dencoder.state_lock = false
        for i in 1:length(feed_in)
            aseencode = BitArray(undef, 100)
            encode_into_array(adaptscalar, expected_out[i], aseencode; learn=true)
            delencode = BitArray(undef, 100)
            encode_into_array(dencoder, feed_in[i], delencode; learn=true)
            @test delencode[1] == aseencode[1]
        end
    end

    @testset "test_locking_state" begin
        adaptscalar = AdaptiveScalarEncoder(21, nothing, nothing, 100; forced=true)
        dencoder = DeltaEncoder(21, nothing, nothing, 100; forced=true)

        feed_in = [1, 10, 4, 7, 9, 6, 3, 1]
        expected_out = [0, 9, -6, 3, 2, -3, -3, -2]

        for i in 1:length(feed_in)
            if i == 4 dencoder.state_lock = true end
            aseencode = BitArray(undef, 100)
            encode_into_array(adaptscalar, expected_out[i], aseencode; learn=true)
            delencode = BitArray(undef, 100)
            if i>=4
                encode_into_array(dencoder, feed_in[i]-feed_in[3], delencode; learn=true)
            else 
                encode_into_array(dencoder, expected_out[i], delencode; learn=true)
            end
            @test delencode[1] == aseencode[1]
        end
    end

    @testset "test_encode_invalid_input_type" begin
        dencoder = DeltaEncoder(21, nothing, nothing, 100; forced=true)
        @test_throws MethodError encode(dencoder, "String")
    end
end