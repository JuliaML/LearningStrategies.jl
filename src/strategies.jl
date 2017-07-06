#-----------------------------------------------------------------------# MaxIter
"""
    MaxIter(n)
Stop learning after `n` iterations.
"""
struct MaxIter <: LearningStrategy
    maxiter::Int
end
MaxIter() = MaxIter(100)
finished(strat::MaxIter, model, i) = i >= strat.maxiter

#-----------------------------------------------------------------------# TimeLimit
"""
    TimeLimit(s)
Stop iterating after `s` seconds.
"""
mutable struct TimeLimit <: LearningStrategy
    secs::Float64
    secs_end::Float64
    TimeLimit(secs::Number) = new(secs)
end
pre_hook(strat::TimeLimit, model) = (strat.secs_end = time() + strat.secs)
function finished(strat::TimeLimit, model, i)
    stop = time() >= strat.secs_end
    stop && info("Time's up!")
    stop
end

#-----------------------------------------------------------------------# ShowStatus
"""
    ShowStatus(b=1)
    ShowStatus(b, f)
Every `b` iterations, print the output of `f(model, i)`.
"""
struct ShowStatus <: LearningStrategy
    every::Int
    f::Function
end
ShowStatus(every::Int = 1) = ShowStatus(every, (model, i) -> "Iteration $i: $(params(model))")
pre_hook(strat::ShowStatus, model) = iter_hook(strat, model, 0)
function iter_hook(strat::ShowStatus, model, i)
    mod1(i, strat.every) == strat.every && println(strat.f(model, i))
    return
end

#-----------------------------------------------------------------------# ConvergenceFunction
"""
    ConvergenceFunction(f)
Stop learning when `f(model, i)` returns true.
"""
struct ConvergenceFunction <: LearningStrategy
    f::Function
end
finished(strat::ConvergenceFunction, model, i)::Bool = strat.f(model, i)

#-----------------------------------------------------------------------# Converged
"""
    Converged(f; tol = 1e-6, every = 1)
Stop learning when `norm(f(model) - lastf) ≦ tol`.
"""
mutable struct Converged <: LearningStrategy
    f::Function   # f(model)
    tol::Float64  # normdiff tolerance
    every::Int    # only check every ith iteration
    lastval::Vector{Float64}
    Converged(f::Function; tol::Number = 1e-6, every::Int = 1) = new(f, tol, every)
end
pre_hook(strat::Converged, model) = (strat.lastval = zeros(strat.f(model)); return)
function finished(strat::Converged, model, i)
    val = strat.f(model)
    if norm(val - strat.lastval) <= strat.tol
        info("Converged after $i iterations: $val")
        true
    else
        copy!(strat.lastval, val)
        false
    end
end
post_hook(strat::Converged, model) = info("Not converged: $(strat.lastval)")

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
function finished(strat::ConvergedTo, model, i)
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
function iter_hook(strat::IterFunction, model, i)
    if mod1(i, strat.every) == strat.every
        strat.f(model, i)
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
function iter_hook(strat::Tracer, model, i)
    if mod1(i, strat.every) == strat.every
        push!(strat.storage, strat.f(model, i))
    end
    return
end
