using Dates

@testset "DateEncoderTest" begin
    
    _e = DateEncoder(; season=3, day_of_week=1, weekend=1, time_of_day=5, forced=true)
    _d = DateTime(2010, 11, 4, 14, 55)
    _bits = encode(_e, _d)

    season_expeceted = [0,0,0,0,0,0,0,0,0,1,1,1]
    day_of_week_expeceted = [0,0,0,1,0,0,0]
    weekend_expected = [1, 0]

    time_of_day_expected = ([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0])

    _expected = vcat(season_expeceted, day_of_week_expeceted, weekend_expected, time_of_day_expected)
    
    
    @testset "test_date_encoder" begin
        @test get_description(_e) == [
            ("season", 1),
            ("day of week", 13),
            ("weekend", 20), 
            ("time of day", 22)
        ]

        @test _expected == _bits
    end


    @testset "test_missing_data" begin
        mv_output = encode(_e, nothing)
        @test sum(mv_output) == 0
    end

   
    @testset "test_decoding" begin
        decoded = decode(_e, _bits)

        fields_dict, _ = decoded
        @test length(fields_dict) == 4

        ranges, _ = fields_dict["season"]
        @test length(ranges) == 1
        @test ranges[1] == [305, 305]

        ranges, _ = fields_dict["time of day"]
        @test length(ranges) == 1
        @test ranges[1] == [14.4, 14.4]
        
        ranges, _ = fields_dict["day of week"]
        @test length(ranges) == 1
        @test ranges[1] == [3, 3]

        ranges, _ = fields_dict["weekend"]
        @test length(ranges) == 1
        @test ranges[1] == [0, 0]
    end 

    
    @testset "test_decoding" begin
        top_down = top_down_compute(_e, _bits)
        top_down_values = [elem.value for elem in top_down]
        errs = top_down_values - [320.25, 3.5, .167, 14.8]
        @test findmax(errs)[1] ≈ 0
    end

    @testset "test_bucket_index_support" begin
        bucket_indices = get_bucket_indices(_e, _d)
        top_down = get_bucket_info(_e, bucket_indices)
        top_down_values = [elem.value for elem in top_down]
        errs = top_down_values - [320.25, 3.5, .167, 14.8]
        @test findmax(errs)[1] ≈ 0

        encodings = []
        for x in top_down
            append!(encodings, x.encoding)
        end
        @test encodings == _expected
    end 

    @testset "test_holiday" begin
        e = DateEncoder(;holiday=5, forced=true)
        holiday = [0,0,0,0,0,1,1,1,1,1]
        notholiday = [1,1,1,1,1,0,0,0,0,0]
        holiday2 = [0,0,0,1,1,1,1,1,0,0]

        d = DateTime(2010, 12, 25, 4, 55)
        @test encode(e, d) == holiday

        d = DateTime(2008, 12, 27, 4, 55)
        @test encode(e, d) == notholiday

        d = DateTime(1999, 12, 26, 8, 00)
        @test encode(e, d) == holiday2

        d = DateTime(2011, 12, 24, 16, 00)
        @test encode(e, d) == holiday2
    end

    @testset "test_multiple_holiday" begin
        e = DateEncoder(;holiday=5, forced=true, holidays=[(12,25), (2018, 4, 1), (2017, 4, 16)])
        holiday = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1]
        notholiday = [1, 1, 1, 1, 1, 0, 0, 0, 0, 0]

        d = DateTime(2011, 12, 25, 4, 55)
        @test encode(e, d) == holiday

        d = DateTime(2007, 12, 2, 4, 55)
        @test encode(e, d) == notholiday

        d = DateTime(2018, 4, 1, 16, 10)
        @test encode(e, d) == holiday

        d = DateTime(2017, 4, 16, 16, 10)
        @test encode(e, d) == holiday
    end

    @testset "test_weekend" begin
        e = DateEncoder(;custom_days=(21, [Saturday, Sunday, Friday]), forced=true)
        mon = DateEncoder(;custom_days=(21, Monday), forced=true)

        e2 = DateEncoder(;weekend=(21, 1), forced=true)
        d = DateTime(1988, 5, 29, 20, 00)

        @test encode(e, d) == encode(e2, d)

        for _ in 1:300
            d = d + Dates.Day(1)
            @test encode(e, d) == encode(e2, d)

            println(decode(mon, encode(mon, d)))
            if decode(mon, encode(mon, d))[1]["Monday"][1][1][1] == 1.0
                @test Dates.dayofweek(d) <= 5
            else 
                @test Dates.dayofweek(d) >= 6
            end
        end
    end
end
