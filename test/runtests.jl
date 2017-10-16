module LearningStrategiesTest

using LearningStrategies, Base.Test
import LearningStrategies: update!

mutable struct Model n::Int end
struct NewStrat <: LearningStrategy end
update!(m::Model, s::NewStrat, item) = (m.n += 1)

#-----------------------------------------------------------------------# Verbose
info("Verbose")
learn!(nothing, Verbose(MaxIter(5)), 1:10)
learn!(nothing, Verbose(TimeLimit(.5)))
learn!(Model(5), Verbose(Converged(m -> m.n == 5)))

#-----------------------------------------------------------------------# Type stability
info("Type Stability")
strat_list = [
    MaxIter(20),
    TimeLimit(2),
    ShowStatus(1, (m, i) -> "$m after $i iterations"),
    ConvergenceFunction((m, i) -> true),
    Converged(m -> m),
    ConvergedTo(m -> m, ones(2)),
    IterFunction((m, i) -> println("this is iteration $i")),
    Tracer(Float64, (m, i) -> mean(m))
]
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
@testset "ConvergenceFunction" begin
    m = Model(0)
    learn!(m, strategy(NewStrat(), ConvergenceFunction((m,i) -> m.n==10)))
    @test m.n == 10
end
@testset "Tracer" begin
    t = Tracer(Int, (mod,i) -> i)
    learn!(nothing, strategy(MaxIter(100), t))
    @test t.storage == collect(1:100)
end
@testset "ShowStatus" begin
    model = nothing
    s = strategy(MaxIter(2), ShowStatus(1, (m, i) -> "    model is still $model"))
    @inferred learn!(model, s)
end
@testset "ConvergedTo" begin
    model = ones(5)
    s = strategy(ConvergedTo(m -> m, ones(5)))
    @inferred learn!(model, s)
end
@testset "IterFunction" begin
    model = ones(5)
    s = strategy(MaxIter(2), IterFunction((m,i) -> println("    print 2 times!")))
    @inferred learn!(model, s)
end
end
