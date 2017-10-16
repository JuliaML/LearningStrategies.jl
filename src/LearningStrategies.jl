__precompile__(true)
module LearningStrategies

import LearnBase: learn!, update!

export
    LearningStrategy, MetaStrategy, strategy, LearnType,
    # LearningStrategies
    Verbose, MaxIter, TimeLimit, ConvergenceFunction, IterFunction, ShowStatus, Tracer,
    Converged, ConvergedTo,
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
finished(s::MetaStrategy, model, data, i) = any(x -> finished(x, model, data, i),  s.strategies)
cleanup!(s::MetaStrategy, model) = foreach(x -> cleanup!(x, model),    s.strategies)

"""
    strategy(s::LearningStrategy...)
    strategy(ms::MetaStrategy, s::LearningStrategy...)

Create a MetaStrategy from LearningStrategies or add a LearningStrategy to an existing MetaStrategy.
"""
strategy(s::LearningStrategy...) = MetaStrategy(s)
strategy(ms::MetaStrategy, s::LearningStrategy...) = MetaStrategy(ms.strategies..., s...)



#-----------------------------------------------------------------------# LearnType
"""
    LearnType.Offline()
    LearnType.Online()

The last argument to `learn!(model, strategy, data, learntype)`.

- `LearnType.Offline()`:  Each item in the main loop is the entire data.
- `LearnType.Offline()`:  Each item in the main loop is from `enumerate`
"""
module LearnType
    struct Offline end
    struct Online  end
end

#-----------------------------------------------------------------------# Online learn!
"""
    learn!(model, strategy, data)

Learn a `model` from `data` using `strategy` in an online fashion.
"""
function learn!(model, s::LearningStrategy, data, ::LearnType.Online = LearnType.Online())
    setup!(s, model, data)
    for (i, item) in enumerate(data)
        update!(model, s, item)
        hook(s, model, data, i)
        finished(s, model, data, i) && break
    end
    cleanup!(s, model)
end

#-----------------------------------------------------------------------# Offline learn!
"""
    learn!(model, strategy, data, learntype = LearnType.Offline())

Learn a `model` from `data` using `strategy` in an offline fashion.
"""
function learn!(model, s::LearningStrategy, data, ::LearnType.Offline)
    setup!(s, model, data)
    i = 1
    while true
        update!(model, s, data)
        hook(s, model, data, i)
        finished(s, model, data, i) && break
        i += 1
    end
    cleanup!(s, model)
end

#-----------------------------------------------------------------------# InfiniteNothing
# learn without input data... good for minimizing functions
struct InfiniteNothing end
Base.start(itr::InfiniteNothing) = 1
Base.done(itr::InfiniteNothing, i) = false
Base.next(itr::InfiniteNothing, i) = (nothing, i + 1)

"""
    learn!(model, strategy)

Learn a `model` using `strategy`.
"""
learn!(model, s::LearningStrategy) = learn!(model, s, InfiniteNothing())




#-----------------------------------------------------------------------#
#                           Below here are built-in LearningStrategies
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------# Verbose
"""
    Verbose(s::LearningStrategy)
    Verbose(s::LearningStrategy, io::IO)

Allow the LearningStrategy `s` to print output.

- Will automatically print when `finished(s, args...) == true`.
- Other methods should be overloaded to add printout.
    - For example: `update!(model, v::Verbose{MyStrategy}, item) = ...`
"""
struct Verbose{S <: LearningStrategy, T <: IO} <: LearningStrategy
    strategy::S
    io::T
end
Verbose(s::LearningStrategy) = Verbose(s, STDOUT)

Base.show(io::IO, v::Verbose) = print(io, "Verbose ", v.strategy)

function finished(v::Verbose, model, data, i)
    done = finished(v.strategy, model, data, i)
    done && info("$(v.strategy) finished")
    done
end


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
function hook(strat::Tracer, model, i)
    if mod1(i, strat.every) == strat.every
        push!(strat.storage, strat.f(model, i))
    end
    return
end

#-----------------------------------------------------------------------# ConvergenceFunction
"""
    ConvergenceFunction(f)

Stop learning when `f(model, i)` returns true.
"""
struct ConvergenceFunction{F<:Function} <: LearningStrategy
    f::F
end
finished(strat::ConvergenceFunction, model, data, i)::Bool = strat.f(model, i)






#-----------------------------------------------------------------------# TODO:





#-----------------------------------------------------------------------# ShowStatus
"""
    ShowStatus(b = 1)
    ShowStatus(b, f)

Every `b` iterations, print the output of `f(model, i)`.
"""
struct ShowStatus <: LearningStrategy
    every::Int
    f::Function
end
ShowStatus(every::Int = 1) = ShowStatus(every, (model, i) -> "Iteration $i: $(params(model))")
setup!(strat::ShowStatus, model, data) = hook(strat, model, 0)
function hook(strat::ShowStatus, model, i)
    mod1(i, strat.every) == strat.every && println(strat.f(model, i))
    return
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
    IterFunction(f, b=1)
Call `f(model, i)` every `b` iterations.
"""
struct IterFunction <: LearningStrategy
    f::Function
    every::Int
end
IterFunction(f::Function; every::Int = 1) = IterFunction(f, every)
function hook(strat::IterFunction, model, i)
    if mod1(i, strat.every) == strat.every
        strat.f(model, i)
    end
    return
end



end # module
