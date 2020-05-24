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

end