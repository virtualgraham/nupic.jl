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

            v += l.resolution / 4
        end
    end
    

end