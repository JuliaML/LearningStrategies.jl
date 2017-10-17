__precompile__(true)
module LearningStrategies

import LearnBase: learn!, update!

export
    LearningStrategy, MetaStrategy, strategy, Offline, InfiniteNothing, 
    # LearningStrategies
    Verbose, MaxIter, TimeLimit, Converged, ConvergedTo, IterFunction, Tracer, Breaker,
    # functions
    setup!, update!, hook, finished, cleanup!, learn!

#---------------------------------------------------------------------# LearningStrategy interface
"""
A LearningStrategy should implement at least one of the following methods:

- `setup!(strat, model, data)`
- `cleanup!(strat, model)`
- `hook(strat, model, i)`
- `finished(strat, model, data, i)`
- `update!(model, strat, item)`
"""
abstract type LearningStrategy end

setup!(s::LearningStrategy, model) = nothing
setup!(s::LearningStrategy, model, data) = setup!(s, model)

update!(model, s::LearningStrategy, item) = nothing

hook(s::LearningStrategy, model, i) = nothing
hook(s::LearningStrategy, model, data, i) = hook(s, model, i)

finished(s::LearningStrategy, model, i) = false
finished(s::LearningStrategy, model, data, i) = finished(s, model, i)

cleanup!(s::LearningStrategy, model) = nothing



#-----------------------------------------------------------------------# MetaStrategy
"""
    MetaStrategy(strats::LearningStrategy...)

A collection of learning strategies in a type-stable way.
"""
struct MetaStrategy{T <: Tuple} <: LearningStrategy
    strategies::T
end
MetaStrategy(s::LearningStrategy...) = MetaStrategy(s)

function Base.show(io::IO, s::MetaStrategy)
    println(io, "MetaStrategy")
    println.(io, "  > ", s.strategies[1:(end-1)])
    print(io, "  > ", s.strategies[end])
end

setup!(ms::MetaStrategy, model, data) = foreach(s -> setup!(s, model, data), ms.strategies)
update!(model, s::MetaStrategy, item) = foreach(x -> update!(model, x, item), s.strategies)
hook(s::MetaStrategy, model, data, i) = foreach(x -> hook(x, model, data, i), s.strategies)
finished(s::MetaStrategy, model, data, i) = any(x -> finished(x, model, data, i), s.strategies)
cleanup!(s::MetaStrategy, model) = foreach(x -> cleanup!(x, model), s.strategies)

"""
    strategy(s::LearningStrategy...)
    strategy(ms::MetaStrategy, s::LearningStrategy...)

Create a MetaStrategy from LearningStrategies or add a LearningStrategy to an existing MetaStrategy.
"""
strategy(s::LearningStrategy...) = MetaStrategy(s)
strategy(ms::MetaStrategy, s::LearningStrategy...) = MetaStrategy(ms.strategies..., s...)


#-----------------------------------------------------------------------# learn!
"""
    learn!(model, strategy, data)

Learn a `model` from `data` using `strategy`.  New models/strategies/data types should overload at least one of the following:

- [`setup!`](@ref)
- [`update!`](@ref)
- [`hook`](@ref)
- [`finished`](@ref)
- [`cleanup!`](@ref)

# `learn!` Implementation:

    function learn!(model, s::LearningStrategy, data)
        setup!(s, model, data)
        for (i, item) in enumerate(data)
            update!(model, s, item)
            hook(s, model, data, i)
            finished(s, model, data, i) && break
        end
        cleanup!(s, model)
    end
"""
function learn!(model, s::LearningStrategy, data)
    setup!(s, model, data)
    for (i, item) in enumerate(data)
        update!(model, s, item)
        hook(s, model, data, i)
        finished(s, model, data, i) && break
    end
    cleanup!(s, model)
end

#-----------------------------------------------------------------------# Offline
"""
    Offline(data)

Send all of `data` into the loop of `learn!(model, strategy, data)` at each iteration.
"""
struct Offline{T}
    data::T
end
Offline(args...) = Offline(args)
Base.start(o::Offline) = 1
Base.done(o::Offline, i) = false
Base.next(o::Offline, i) = (o.data, i + 1)

#-----------------------------------------------------------------------# InfiniteNothing
# learn without input data... good for minimizing functions
struct InfiniteNothing end
Base.start(itr::InfiniteNothing) = 1
Base.done(itr::InfiniteNothing, i) = false
Base.next(itr::InfiniteNothing, i) = (nothing, i + 1)

learn!(model, s::LearningStrategy) = learn!(model, s, InfiniteNothing())




################################################################################## Strategies

#-----------------------------------------------------------------------# Verbose
"""
    Verbose(s::LearningStrategy)
    Verbose(s::LearningStrategy, io::IO)

Allow the LearningStrategy `s` to print output.

- Will automatically print when `finished(s, args...) == true`.
- Other methods should be overloaded to add printout.
    - For example: `update!(model, v::Verbose{MyStrategy}, item) = ...`
"""
struct Verbose{S <: LearningStrategy} <: LearningStrategy
    strategy::S
end

Base.show(io::IO, v::Verbose) = print(io, "Verbose ", v.strategy)

setup!(v::Verbose, model, data) = setup!(v.strategy, model, data)
update!(v::Verbose, model, item) = update!(v.strategy, model, item)
hook(v::Verbose, model, i) = hook(v.strategy, model, i)
function finished(v::Verbose, model, data, i)
    done = finished(v.strategy, model, data, i)
    done && info("$(v.strategy) finished")
    done
end
cleanup!(v::Verbose, model) = cleanup!(v.strategy, model)


#-----------------------------------------------------------------------# MaxIter
"""
    MaxIter(n)

Stop learning after `n` iterations.
"""
struct MaxIter <: LearningStrategy
    n::Int
end
MaxIter() = MaxIter(100)
Base.show(io::IO, s::MaxIter) = print(io, "MaxIter($(s.n))")
finished(s::MaxIter, model, data, i) = i >= s.n

#-----------------------------------------------------------------------# TimeLimit
"""
    TimeLimit(s)

Stop learning after `s` seconds.
"""
mutable struct TimeLimit <: LearningStrategy
    secs::Float64
    secs_end::Float64
    TimeLimit(secs::Number) = new(secs)
end
Base.show(io::IO, s::TimeLimit) = print(io, "TimeLimit($(s.secs))")
setup!(strat::TimeLimit, model, data) = (strat.secs_end = time() + strat.secs)
finished(strat::TimeLimit, model, data, i) = time() >= strat.secs_end

#-----------------------------------------------------------------------# Converged
"""
    Converged(f; tol = 1e-6, every = 1)

Stop learning when `norm(f(model) - lastf) ≦ tol`.
"""
mutable struct Converged{F <: Function} <: LearningStrategy
    f::F          # f(model)
    tol::Float64  # normdiff tolerance
    every::Int    # only check every ith iteration
    lastval::Vector{Float64}
end
Converged(f::Function; tol::Number = 1e-6, every::Int = 1) = Converged(f, tol, every, zeros(0))

Base.show(io::IO, s::Converged) = print(io, "Converged($(s.f), $(s.tol), $(s.every))")

setup!(s::Converged, model, data) = (s.lastval = zeros(s.f(model)); return)

function finished(strat::Converged, model, data, i)
    val = strat.f(model)
    if norm(val - strat.lastval) <= strat.tol
        true
    else
        copy!(strat.lastval, val)
        false
    end
end
function finished(v::Verbose{<:Converged}, model, data, i)
    done = finished(v.strategy, model, data, i)
    done && info("Converged after $i iterations: $(v.strategy.f(model))")
    done
end

#-----------------------------------------------------------------------# ConvergedTo
"""
    ConvergedTo(f, goal; tol=1e-6, every=1)

Stop learning when `‖f(model) - goal‖ ≦ tol`.
"""
struct ConvergedTo{V} <: LearningStrategy
    f::Function   # f(model)
    tol::Float64  # normdiff tolerance
    goal::V       # goal value
    every::Int    # only check every ith iteration
end
function ConvergedTo(f::Function, goal; tol::Number = 1e-6, every::Int = 1)
    ConvergedTo(f, tol, goal, every)
end
Base.show(io::IO, s::ConvergedTo) = print(io, "ConvergedTo($(s.f), $(s.tol), $(s.goal), $(s.every))")
function finished(strat::ConvergedTo, model, data, i)
    val = strat.f(model)
    if norm(val - strat.goal) <= strat.tol
        info("Converged after $i iterations: $val")
        true
    else
        false
    end
end

#-----------------------------------------------------------------------# IterFunction
"""
    IterFunction(f, b)
    IterFunction(b, f)

Call `f(model, i)` every `b` iterations.
"""
struct IterFunction{F<:Function} <: LearningStrategy
    f::F
    b::Int
end
IterFunction(f::Function) = IterFunction(f, 1)
IterFunction(b::Int, f::Function) = IterFunction(f, b)

Base.show(io::IO, o::IterFunction) = print(io, "IterFunction($(o.f), $(o.b))")

function hook(s::IterFunction, model, i)
    if mod1(i, s.b) == s.b
        s.f(model, i)
    end
    return
end

#-----------------------------------------------------------------------# Tracer
"""
    Tracer{T}(::Type{T}, f, b=1)

Store `f(model, i)` every `b` iterations.
"""
struct Tracer{S} <: LearningStrategy
    every::Int
    f::Function
    storage::Vector{S}
end
Tracer{S}(::Type{S}, f::Function, every::Int = 1) = Tracer(every, f, S[])
Base.show(io::IO, s::Tracer) = print(io, "Tracer($(s.every), $(s.f), $(summary(s.storage))")
function hook(strat::Tracer, model, i)
    if mod1(i, strat.every) == strat.every
        push!(strat.storage, strat.f(model, i))
    end
    return
end

#-----------------------------------------------------------------------# Breaker
"""
    Breaker(f)

Stop learning when `f(model, i)` returns true.
"""
struct Breaker{F<:Function} <: LearningStrategy
    f::F
end
Base.show(io::IO, s::Breaker) = print(io, "Breaker($(s.f))")
finished(strat::Breaker, model, data, i)::Bool = strat.f(model, i)








end # module
