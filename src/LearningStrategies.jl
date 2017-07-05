__precompile__(true)

module LearningStrategies

# ----------------------------------------------------------------------

using LearnBase
import LearnBase: learn!, update!

export
    LearningStrategy, MetaLearner, make_learner, LearnType,
    # LearningStrategies
    MaxIter, TimeLimit, ConvergenceFunction, IterFunction, ShowStatus, Tracer,
    Converged, ConvergedTo,
    # functions
    pre_hook, iter_hook, learn!, update!, post_hook, finished

# ----------------------------------------------------------------------

"""
A LearningStrategy should implement at least one of the following methods:

- `pre_hook(strat, model)`
- `post_hook(strat, model)`
- `iter_hook(strat, model, i)`
- `finished(strat, model, i)`
- `update!(model, strat, item)`
"""
abstract type LearningStrategy end

# fallbacks don't do anything
pre_hook(strat::LearningStrategy, model)      = return
iter_hook(strat::LearningStrategy, model, i)  = return
post_hook(strat::LearningStrategy, model)     = return
finished(strat::LearningStrategy, model, i)   = false
update!(model, strat::LearningStrategy, item) = return

# ----------------------------------------------------------------------

include("metalearner.jl")
include("strategies.jl")

# ----------------------------------------------------------------------

end # module
