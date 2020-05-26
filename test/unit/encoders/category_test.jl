@testset "CategoryEncoderTest" begin
    
    @testset "test_category_encoder" begin
        categories = ["ES", "GB", "US"]

        e = CategoryEncoder(3, categories; forced=true)
        output = encode(e, "US")
        expected = [0,0,0,0,0,0,0,0,0,1,1,1]
        println(output)
        println(expected)
        @test output == expected

        
    end

end