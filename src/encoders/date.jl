using Dates

abstract type AbstractDateEncoder <: AbstractEncoder end

mutable struct DateEncoder <: AbstractDateEncoder
    super::Encoder
    width::Integer
    description::Vector{Tuple{String, Integer}}
    season_encoder::Union{Nothing, ScalarEncoder}
    season_offset::Union{Nothing, Integer}
    day_of_week_encoder::Union{Nothing, ScalarEncoder}
    day_of_week_offset::Union{Nothing, Integer}
    weekend_encoder::Union{Nothing, ScalarEncoder}
    weekend_offset::Union{Nothing, Integer}
    custom_days_encoder::Union{Nothing, ScalarEncoder}
    custom_days::Union{Nothing, Vector{Int64}}
    custom_days_offset::Union{Nothing, Integer}
    holiday_encoder::Union{Nothing, ScalarEncoder}
    holiday_offset::Union{Nothing, Integer}
    holidays::Union{Nothing, Array{Tuple{Int64,Int64,Vararg{Int64,N} where N},1}}
    time_of_day_encoder::Union{Nothing, ScalarEncoder}
    time_of_day_offset::Union{Nothing, Integer}

    function DateEncoder(;
        season::Union{Integer, Tuple{Integer,Real}}=0,
        day_of_week::Union{Integer, Tuple{Integer,Real}}=0,
        weekend::Union{Integer, Tuple{Integer,Real}}=0,
        time_of_day=0,
        custom_days::Union{Nothing, Tuple{Int64, Union{Vector{Int64}, Int64}}} = nothing,
        name="",
        forced=false,
        holiday=0,
        holidays::Union{Nothing, Array{Tuple{Int64,Int64,Vararg{Int64,N} where N},1}}=nothing
    )
        encoders::Vector{Tuple{String, AbstractEncoder, Integer}} = []
        width::Integer = 0
        description = []
        season_encoder = nothing
        season_offset = nothing
        day_of_week_encoder = nothing
        day_of_week_offset = nothing
        weekend_encoder = nothing
        weekend_offset = nothing
        custom_days_encoder = nothing
        days = nothing
        custom_days_offset = nothing
        holiday_encoder = nothing
        holiday_offset = nothing
        time_of_day_encoder = nothing
        time_of_day_offset = nothing


        if season != 0
            if season isa Tuple
                w = season[1]
                radius = season[2]
            else
                w = season
                radius = 91.5
            end

            season_encoder = ScalarEncoder(w, 0, 366; radius=radius, periodic=true, name="season", forced=forced)
            season_offset = width + 1
            width += get_width(season_encoder)
            push!(description, ("season", season_offset))
            push!(encoders, ("season", season_encoder, season_offset))
        end

        if day_of_week != 0
            if day_of_week isa Tuple
                w = day_of_week[1]
                radius = day_of_week[2]
            else
                w = day_of_week
                radius = 1
            end

            day_of_week_encoder = ScalarEncoder(w, 0, 7; radius=radius, periodic=true, name="day of week", forced=forced)
            day_of_week_offset = width + 1
            width += get_width(day_of_week_encoder)
            push!(description, ("day of week", day_of_week_offset))
            push!(encoders, ("day of week", day_of_week_encoder, day_of_week_offset))
        end

        if weekend != 0
            if !(weekend isa Tuple)
                weekend = (weekend, 1) 
            end

            weekend_encoder = ScalarEncoder(weekend[1], 0, 1; radius=weekend[2], periodic=false, name="weekend", forced=forced)
            weekend_offset = width + 1
            width += get_width(weekend_encoder)
            push!(description, ("weekend", weekend_offset))
            push!(encoders, ("weekend", weekend_encoder, weekend_offset))
        end
        
        if custom_days !== nothing
            custom_days_encoder_name = ""

            if custom_days[2] isa Vector
                for day in custom_days[2]
                    custom_days_encoder_name *= (Dates.dayname(day) * " ")
                end
                days = custom_days[2]
            else 
                custom_days_encoder_name *= Dates.dayname(custom_days[2])
                days = [custom_days[2]]
            end

            custom_days_encoder = ScalarEncoder(custom_days[1], 0, 1; radius=1, periodic=false, name=custom_days_encoder_name, forced=forced)
            custom_days_offset = width + 1
            width += get_width(custom_days_encoder)
            push!(description, ("customdays", custom_days_offset))
            push!(encoders, ("customdays", custom_days_encoder, custom_days_offset))
        end


        if holiday != 0
            holiday_encoder = ScalarEncoder(holiday, 0, 1; radius=1, periodic=false, name="holiday", forced=forced)
            holiday_offset = width + 1
            width += get_width(holiday_encoder)
            push!(description, ("holiday", holiday_offset))
            push!(encoders, ("holiday", holiday_encoder, holiday_offset))
            if holidays === nothing
                holidays = []
            end
        end

        if time_of_day != 0
            if time_of_day isa Tuple
                w = time_of_day[1]
                radius = time_of_day[2]
            else
                w = time_of_day
                radius = 4
            end

            

            time_of_day_encoder = ScalarEncoder(w, 0, 24; radius=radius, periodic=true, name="time of day", forced=forced)
            time_of_day_offset = width + 1
            width += get_width(time_of_day_encoder)
            push!(description, ("time of day", time_of_day_offset))
            push!(encoders, ("time of day", time_of_day_encoder, time_of_day_offset))
        end

        super = Encoder(name, encoders)

        return new(
            super,
            width,
            description,
            season_encoder,
            season_offset,
            day_of_week_encoder,
            day_of_week_offset,
            weekend_encoder,
            weekend_offset,
            custom_days_encoder,
            days,
            custom_days_offset,
            holiday_encoder,
            holiday_offset,
            holidays,
            time_of_day_encoder,
            time_of_day_offset
        )
    end
end


get_width(encoder::AbstractDateEncoder) = encoder.width
get_description(encoder::AbstractDateEncoder) = encoder.description


function get_scalar_names(encoder::AbstractDateEncoder, parent_field_name="")
    names = []

    function from_field_name(encoder)
        if parent_field_name == ""
            return encoder.name
        else
            return "$parent_field_name.$(encoder.name)"
        end
    end

    if encoder.season_encoder !== nothing
        push!(names, from_field_name(encoder.season_encoder))
    end
    if encoder.day_of_week_offset !== nothing
        push!(names, from_field_name(encoder.day_of_week_offset))
    end
    if encoder.custom_days_encoder !== nothing
        push!(names, from_field_name(encoder.custom_days_encoder))
    end
    if encoder.weekend_encoder !== nothing
        push!(names, from_field_name(encoder.weekend_encoder))
    end
    if encoder.holiday_encoder !== nothing
        push!(names, from_field_name(encoder.holiday_encoder))
    end
    if encoder.time_of_day_encoder !== nothing
        push!(names, from_field_name(encoder.time_of_day_encoder))
    end

    return names
end


function get_encoded_values(encoder::AbstractDateEncoder, input)
    if input === nothing
        return [nothing]
    end

    @assert input isa DateTime

    values = []

    time_of_day = Dates.hour(input) + Dates.minute(input)/60.0 + Dates.millisecond(input)/60000.0

    if encoder.season_encoder !== nothing
        day_of_year = Dates.dayofyear(input) - 1
        push!(values, day_of_year)
    end

    if encoder.day_of_week_encoder !== nothing
        day_of_week = (Dates.dayofweek(input) - 1.0) + time_of_day/24.0
        push!(values, day_of_week)
    end

    if encoder.weekend_encoder !== nothing
        day_of_week = Dates.dayofweek(input)
        if day_of_week == 7 || day_of_week == 6 || day_of_week == 5 && time_of_day > 18
            weekend = 1
        else
            weekend = 0
        end
        push!(values, weekend)
    end

    if encoder.custom_days_encoder !== nothing
        day_of_week = Dates.dayofweek(input)
        if day_of_week in encoder.custom_days
            custom_day = 1
        else
            custom_day = 0
        end
        push!(values, custom_day)
    end

    if encoder.holiday_encoder !== nothing
        if length(encoder.holidays) == 0
            holidays = [(12, 25)]
        else 
            holidays = encoder.holidays
        end
        val = 0
        for h in holidays
            if length(h) == 3
                hdate = DateTime(h[1], h[2], h[3])
            else
                hdate = DateTime(Dates.year(input), h[1], h[2])
            end
            if input > hdate 
                diff = input - hdate
                days = Dates.days(diff)
                if days == 0
                    val = 1
                    break
                elseif days == 1
                    partial_day = diff.value % 86400000.0
                    val = 1.0 - partial_day/86400000.0
                    break
                end
            else
                diff = hdate - input
                if Dates.days(diff) == 0
                    partial_day = diff.value % 86400000.0
                    val = 1.0 - partial_day/86400000.0
                end
            end
        end
        push!(values, val)
    end

    if encoder.time_of_day_encoder !== nothing
        push!(values, time_of_day)
    end

    return values
end

get_scalars(encoder::AbstractDateEncoder, input) = get_encoded_values(encoder, input)


function get_bucket_indices(this::AbstractDateEncoder, input)
    if input === nothing
        return fill(nothing, length(this.encoders))
    else
        @assert input isa DateTime

        scalars = get_scalars(this, input)

        result = []
        for i in 1:length(this.encoders)
            name, encoder, offset = this.encoders[i]
            append!(result, get_bucket_indices(encoder, scalars[i]))
        end
        return result
    end
end


function encode_into_array(encoder::AbstractDateEncoder, input, output::AbstractArray{Bool}; learn=nothing)
    if input === nothing
        output[:] .= 0
    else
        @assert input isa DateTime

        scalars = get_scalars(encoder, input)

        for i in 1:length(encoder.encoders)
            name, encoder_, offset = encoder.encoders[i]
            encode_into_array(encoder_, scalars[i], view(output, offset:lastindex(output)))
        end
    end
end

