module LearningStrategiesTest

using LearningStrategies, Base.Test
import LearningStrategies: update!

mutable struct Model n::Int end
struct NewStrat <: LearningStrategy end
update!(m::Model, s::NewStrat, item) = (m.n += 1)

#-----------------------------------------------------------------------# Verbose
info("Verbose")
learn!(nothing, Verbose(MaxIter(5)), 1:10)
learn!(nothing, Verbose(TimeLimit(.1)))
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


#
# @testset "MaxIter/IterFunction" begin
#     model = [0]
#     s = strategy(MaxIter(20), IterFunction((m,i) -> (m[1] += 1)))
#     @inferred learn!(model, s)
#     @test model[1] == 20
# end
#
# @testset "TimeLimit" begin
#     model = nothing
#     s = strategy(TimeLimit(2))
#     t1 = time()
#     @inferred learn!(model, s)
#     elapsed = time() - t1
#     @test elapsed < 3
# end

# @testset "ShowStatus" begin
#     model = nothing
#     s = make_learner(MaxIter(2), ShowStatus(1, (m, i) -> "    model is still $model"))
#     @inferred learn!(model, s)
# end
#
# @testset "ConvergenceFunction" begin
#     model = nothing
#     s = make_learner(ConvergenceFunction((m,i) -> true))
#     @inferred learn!(model, s)
# end
#
# @testset "Converged" begin
#     model = ones(5)
#     s = make_learner(Converged(m -> m))
#     @inferred learn!(model, s)
# end
#
# @testset "ConvergedTo" begin
#     model = ones(5)
#     s = make_learner(ConvergedTo(m -> m, ones(5)))
#     @inferred learn!(model, s)
# end
#
# @testset "IterFunction" begin
#     model = ones(5)
#     s = make_learner(MaxIter(2), IterFunction((m,i) -> println("    print 2 times!")))
#     @inferred learn!(model, s)
# end
#
# @testset "Tracer" begin
#     model = 1.0
#     s = make_learner(MaxIter(3), Tracer(Float64, (m,i) -> m))
#     @inferred learn!(model, s)
#     @test s.managers[2].storage == ones(3)
# end



end
