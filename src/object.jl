abstract type Object end

function Base.getproperty(o::Object, s::Symbol)
    if hasfield(typeof(o), s) 
        return getfield(o, s)
    end
    return getproperty(getfield(o, :super), s)
end

function Base.setproperty!(o::Object, s::Symbol, x)
    t = typeof(o)
    if hasfield(t, s) 
        setfield!(o, s, convert(fieldtype(t, s), x))
    else
        setproperty!(getfield(o, :super), s, x)
    end
end