module LearningStrategiesTest
using LearningStrategies
using Base.Test

add_one!(m, i) = (m[1] += 1)

@testset "MaxIter/IterFunction" begin
    model = [0]
    s = make_learner(MaxIter(20), IterFunction(add_one!))
    learn!(model, s)
    @test model[1] == 20
end

@testset "TimeLimit" begin
    model = nothing
    s = make_learner(TimeLimit(2))
    t1 = time()
    learn!(model, s)
    elapsed = time() - t1
    @test elapsed < 3
end

@testset "ShowStatus" begin
    model = nothing
    s = make_learner(MaxIter(2), ShowStatus(1, (m, i) -> "    model is still $model"))
    learn!(model, s)
end

@testset "ConvergenceFunction" begin
    model = nothing
    s = make_learner(ConvergenceFunction((m,i) -> true))
    learn!(model, s)
end



end
