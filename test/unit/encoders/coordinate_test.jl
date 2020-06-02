using SimpleMock

@testset "CoordinateEncoderTest" begin
    
    encoder = CoordinateEncoder(3, 33, "coordinate")

    @testset "test_invalid_w_encoder" begin
        @test_throws ErrorException CoordinateEncoder(4, 45, "coordinate")
        @test_throws ErrorException CoordinateEncoder(0, 45, "coordinate")
        @test_throws ErrorException CoordinateEncoder(-2, 45, "coordinate")
    end

    @testset "test_invalid_n" begin
        @test_throws ErrorException CoordinateEncoder(3, 11, "coordinate")
    end

    @testset "test_hash_coordinate" begin
        h1 = hash_coordinate([0])
        @test h1 == 7800399987794396343
        h2 = hash_coordinate([0, 1])
        @test h2 == 6375019585858399334
    end

    @testset "test_order_for_coordinate" begin
        h1 = order_for_coordinate([2,5,10])
        h2 = order_for_coordinate([2,5,11])
        h3 = order_for_coordinate([2497477, -923478])

        @test 0 < h1 && h1 <= 1
        @test 0 < h2 && h2 <= 1
        @test 0 < h3 && h3 <= 1

        @test h1 != h2
        @test h2 != h3
    end

    @testset "test_bit_for_coordinate" begin
        n= 1000
        b1 = bit_for_coordinate([2,5,10], n)
        b2 = bit_for_coordinate([2,5,11], n)
        b3 = bit_for_coordinate([2497477, -923478], n)

        @test 0 < b1 && b1 <= n
        @test 0 < b2 && b2 <= n
        @test 0 < b3 && b3 <= n
 
        @test b1 != b2
        @test b2 != b3

        n = 2
        b4 = bit_for_coordinate([5,10], n)
        @test 0 < b4 && b4 <= n
    end

    @testset "test_top_w_coordinates" begin
        mock((order_for_coordinate) => (coordinate) -> return sum(coordinate) / 5.0) do _
            coordinates = [[1], [2], [3], [4], [5]]
            top = top_w_coordinates(coordinates, 2)

            @test length(top) == 2
            @test [5] in top
            @test [4] in top 
        end
    end

    @testset "test_neighbors_1d" begin

    end 

    @testset "test_neighbors_2d" begin
    
    end 

    @testset "test_neighbors_0_radius" begin
    
    end 
end