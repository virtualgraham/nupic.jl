mutable struct MovingAverage
    window_size::Integer
    sliding_window::Vector
    total::Float64

    function MovingAverage(
        window_size::Integer,
        existing_historical_values::Union{Nothing, Vector}=nothing
    )
        if window_size <= 0
            error("MovingAverage - windowSize must be >0")
        end

        if existing_historical_values !== nothing
            l = lastindex(existing_historical_values)
            sliding_window = existing_historical_values[l-window_size+1:l]
        else
            sliding_window = Float64[]
        end

        total = sum(sliding_window)
        
        return new(
            window_size,
            sliding_window,
            total
        )
    end
end

function compute(sliding_window, total, new_val, window_size)
    if length(sliding_window) == window_size
        total -= popfirst!(sliding_window)
    end

    push!(sliding_window, new_val)
    total += new_val
    return Float64(total) / length(sliding_window), sliding_window, total
end

function next(average::MovingAverage, new_value)
    new_average, average.sliding_window, average.total = compute(average.sliding_window, average.total, new_value, average.window_size)
    return new_average
end

get_sliding_window(average::MovingAverage) = average.sliding_window

get_current_avg(average::MovingAverage) = average.total / length(average.sliding_window)

function Base.:(==)(x::MovingAverage, y::MovingAverage)
    return x.window_size == y.window_size &&
    x.total == y.total && 
    x.sliding_window == y.sliding_window
end