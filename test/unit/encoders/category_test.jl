@testset "CategoryEncoderTest" begin
    
    @testset "test_category_encoder" begin
        categories = ["ES", "GB", "US"]

        e = CategoryEncoder(3, categories; forced=true)
        output = encode(e, "US")
        expected = [0,0,0,0,0,0,0,0,0,1,1,1]
        @test output == expected

        decoded = decode(e, output)
        fields_dict, field_names = decoded
        @test length(field_names) == 1
        @test length(fields_dict) == 1
        @test field_names[1] == iterate(keys(fields_dict))[1]
        ranges, desc = iterate(values(fields_dict))[1]
        @test desc == "US"
        @test length(ranges) == 1
        @test ranges[1] == [4,4]

        for v in categories
            output = encode(e, v)
            top_down = top_down_compute(e, output)
            @test top_down.value == v
            @test top_down.scalar == get_scalars(e, v)[1]

            bucket_indices = get_bucket_indices(e, v)
            top_down = get_bucket_info(e, bucket_indices)[1]
            @test top_down.value == v
            @test top_down.scalar == get_scalars(e, v)[1]
            @test top_down.encoding == output
            @test top_down.value == get_bucket_values(e)[bucket_indices[1]]
        end



        output = encode(e, "NA")
        expected = [1,1,1,0,0,0,0,0,0,0,0,0]
        @test output == expected

        decoded = decode(e, output)
        fields_dict, field_name = decoded
        @test length(field_names) == 1
        @test length(fields_dict) == 1
        @test field_names[1] == iterate(keys(fields_dict))[1]
        ranges, desc = iterate(values(fields_dict))[1]
        @test length(ranges) == 1
        @test ranges[1] == [1,1]

        top_down = top_down_compute(e, output)
        @test top_down.value == UNKNOWN
        @test top_down.scalar == 1

        

        output = encode(e, "ES")
        expected = [0,0,0,1,1,1,0,0,0,0,0,0]
        @test output == expected

        output_for_missing = encode(e, nothing)
        @test sum(output_for_missing) == 0

        decoded = decode(e, output)
        fields_dict, field_name = decoded
        @test length(field_name) == 1
        @test length(fields_dict) == 1
        @test field_names[1] == iterate(keys(fields_dict))[1]
        ranges, desc = iterate(values(fields_dict))[1]
        @test length(ranges) == 1
        @test ranges[1] == [2,2]

        top_down = top_down_compute(e, output)
        @test top_down.value == "ES"
        @test top_down.scalar == get_scalars(e, "ES")[1]



        fill!(output, 1)

        decoded = decode(e, output)
        fields_dict, field_name = decoded
        @test length(field_names) == 1
        @test length(fields_dict) == 1
        @test field_names[1] == iterate(keys(fields_dict))[1]
        ranges, desc = iterate(values(fields_dict))[1]
        @test length(ranges) == 1
        @test ranges[1] == [1,4]



        categories = ["cat1", "cat2", "cat3", "cat4", "cat5"]
        e = CategoryEncoder(1, categories; forced=true)
        for cat in categories
            output = encode(e, cat)
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]
        end



        categories = ["cat$x" for x in 1:9]
        e = CategoryEncoder(9, categories; forced=true)
        for cat in categories
            output = encode(e, cat)
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]

            output_nzs = findall(x->x>0, output) 
            output[output_nzs[1]] = 0
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]

            output[output_nzs[1]] = 1
            output[output_nzs[lastindex(output_nzs)]] = 0
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]

            fill!(output, 0)
            output[output_nzs[lastindex(output_nzs)-4:lastindex(output_nzs)]] .= 1
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]

            fill!(output, 0)
            output[output_nzs[1:5]] .= 1
            top_down = top_down_compute(e, output)
            @test top_down.value == cat
            @test top_down.scalar == get_scalars(e, cat)[1]
        end


        
        output_1 = encode(e, "cat1")
        output_2 = encode(e, "cat2")
        output = output_1 + output_2
        top_down = top_down_compute(e, output)
        @test top_down.scalar == get_scalars(e, "cat1")[1] || top_down.scalar == get_scalars(e, "cat9")[1]
    end
end