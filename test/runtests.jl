module LearningStrategiesTest

import Base.Iterators: repeated

using LearningStrategies, Statistics, Test
import LearningStrategies: update!

mutable struct Model n::Int end
struct NewStrat <: LearningStrategy end
update!(m::Model, s::NewStrat, item) = (m.n += 1)

#-----------------------------------------------------------------------# Verbose
@info("Verbose")
learn!(nothing, Verbose(MaxIter(5)), 1:10)
learn!(nothing, Verbose(TimeLimit(.5)))
learn!(Model(5), Verbose(Converged(m -> m.n == 5)))

#-----------------------------------------------------------------------# Type stability
@info("Type Stability and Printing")
@testset "Type Stability and Printing" begin
    strat_list = [
        MaxIter(20),
        TimeLimit(2),
        Converged(m -> m),
        ConvergedTo(m -> m, ones(2)),
        IterFunction((m, i) -> i),
        Breaker((m, i) -> true),
        Tracer(Float64, (m, i) -> mean(m))
    ]
    println(strategy(strat_list...))
    m = ones(2)
    i = 5
    for s in strat_list
        println("  > ", s)
        @inferred setup!(s, m, nothing)
        @inferred cleanup!(s, m)
        @inferred hook(s, m, i)
        @inferred finished(s, m, nothing, i)
        @inferred update!(m, s, i)
    end
end

#-----------------------------------------------------------------------# "Real" Tests
@testset "MaxIter" begin
    for j in 1:10
        m = Model(0)
        learn!(m, strategy(MaxIter(j), NewStrat()), 1:100)
        @test m.n == j
    end
end

@testset "TimeLimit" begin
    t1 = time()
    learn!(nothing, TimeLimit(.5))
    elapsed = time() - t1
    @test .5 <= elapsed < 1
end

@testset "Converged" begin
    learn!(nothing, Converged(x -> 1))
end

@testset "ConvergedTo" begin
    model = ones(5)
    s = strategy(ConvergedTo(m -> m, ones(5)))
    @inferred learn!(model, s)
end

@testset "IterFunction" begin
    s = IterFunction(1, (m,i) -> println("Print twice:  > $i"))
    learn!(nothing, strategy(s, MaxIter(2)))
end

@testset "Tracer" begin
    t = Tracer(Int, (mod,i) -> i)
    learn!(nothing, strategy(MaxIter(100), t))
    @test collect(t) == collect(1:100)

    # collect will copy
    A = collect(t)
    A[1] = 42
    @test collect(t) == collect(1:100)
end

@testset "Breaker" begin
    m = Model(0)
    learn!(m, strategy(NewStrat(), Breaker((m,i) -> m.n==10)))
    @test m.n == 10
end

#-------------------------------------------------------------------# Linear Regression Example
struct LinRegModel
    β::Vector
end
struct LinRegSolver <: LearningStrategy end
update!(m::LinRegModel, s::LinRegSolver, item) = (m.β[:] = item[1] \ item[2])

@testset "LinRegModel" begin
    n, p = 1000, 50
    x = randn(n, p)
    y = x * range(-1, stop=1, length=p) + randn(n)

    model = LinRegModel(zeros(p))
    s = strategy(MaxIter(1), LinRegSolver())
    data = repeated((x, y))
    learn!(model, s, data)
    @test model.β == x \ y
end

#-------------------------------------------------------------------# Test Counter

mutable struct Counter <: LearningStrategy
    n::Int
    Counter() = new(0)
end

function update!(m, s::Counter, i, item)
    s.n += 1
    @test s.n == i
end

@testset "update!(m, s, i, item)" begin
  s = strategy(Verbose(MaxIter(5)), Counter())
    learn!(nothing, s)

    learn!(nothing, Counter(), repeated(42, 5))
end


end  # module LearningStrategiesTest
