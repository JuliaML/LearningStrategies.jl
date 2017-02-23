using LearningStrategies
using Base.Test

model = nothing
ii = 0
strat = make_learner(MaxIter(20), IterFunction((m,i) -> (global ii; ii=i)))

learn!(model, strat)
@test ii == 20
