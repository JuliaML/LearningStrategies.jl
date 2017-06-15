__precompile__(true)

module LearningStrategies

# ----------------------------------------------------------------------

using LearnBase
import LearnBase: learn!

export
    LearningStrategy,
    MetaLearner,
    make_learner,

    MaxIter,
    TimeLimit,
    ConvergenceFunction,
    IterFunction,
    ShowStatus,
    Tracer,
    Converged,
    ConvergedTo,

    pre_hook,
    iter_hook,
    learn!,
    post_hook,
    finished

# ----------------------------------------------------------------------

abstract type LearningStrategy end

# fallbacks don't do anything
pre_hook(strat::LearningStrategy, model)      = return
iter_hook(strat::LearningStrategy, model, i)  = return
post_hook(strat::LearningStrategy, model)     = return
finished(strat::LearningStrategy, model, i)   = false
learn!(model, strat::LearningStrategy, data)  = return

# ----------------------------------------------------------------------

include("metalearner.jl")
include("strategies.jl")

# ----------------------------------------------------------------------

end # module
