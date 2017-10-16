# LearningStrategies
| Master Build | Discussion |
|--------------|------------|
| [![Build Status](https://travis-ci.org/JuliaML/LearningStrategies.jl.svg?branch=master)](https://travis-ci.org/JuliaML/LearningStrategies.jl) | [![Gitter chat](https://badges.gitter.im/JuliaML/chat.svg)](https://gitter.im/JuliaML/chat) |

**LearningStrategies is a modular framework for building iterative algorithms in Julia**.  

## Basics

Many algorithms can be generalized to the following pseudocode:

```
setup
while not finished:
    (update model)
    (iteration logic)
cleanup
```



## MetaStrategy
The core function of LearningStrategies is a straightforward implementation of the above loop.  A `model` can be learned by an `LearningStrategy` or a collection of strategies in a `MetaStrategy`.

```julia
function learn!(model, strat::LearningStrategy, data)
    setup!(strat, model)
    for (i, item) in enumerate(data)
        update!(model, strat, item)
        hook(strat, model, i)
        finished(strat, model, i) && break
    end
    cleanup!(strat, model)
end
```

## Example

```julia
using LearningStrategies
import LearningStrategies: update!

struct Model
    params::Vector{Float64}
end
function update!(m::Model, s::LearningStrategy, item)
    rand!(m.params)
end

m = Model(rand(5))
learn!(m, MaxIter(5))
learn!(m, Verbose(MaxIter(5)))
```

At the core of LearningStrategies is the `MetaStrategy` type, which binds together many functionally independent learning strategies and controls the iterative loop.  The core loop is:

```julia
function learn!(model, meta::Strategy, data)
    setup!(meta, model)
    for (i, item) in enumerate(data)
        update!(model, meta, item)
        hook(meta, model, i)
        finished(meta, model, i) && break
    end
    cleanup!(meta, model)
end
```

Each of these callbacks will trigger the implemented callbacks of the sub-strategies, allowing you to compile complex behavior from simple components.

The above loop sends data to the MetaLearner in an online fashion.  LearningStrategies can also be used for offline algorithms via
```julia
learn!(model, meta, data, LearnType.Offline())
```

```julia
function learn!(model, meta::MetaLearner, data, ::LearnType.Offline)
    pre_hook(meta, model)
    i = 1
    while true
        update!(model, meta, data)
        iter_hook(meta, model, i)
        finished(meta, model, i) && break
        i += 1
    end
    post_hook(meta, model)
end
```


## Simple example

```julia
julia> using LearningStrategies

julia> model = nothing

julia> strat = make_learner(TimeLimit(2))
LearningStrategies.MetaLearner{Tuple{LearningStrategies.TimeLimit}}((LearningStrategies.TimeLimit(2.0,0.0),))

julia> @time learn!(model, strat)
INFO: Time's up!
  2.068520 seconds (39.50 k allocations: 1.735 MB)
```

Following through this very short example, we see that we have built a MetaLearner that contains a single sub-strategy: a 2-second time limit.  The TimeLimit strategy has a simple implementation:

```julia
"Stop iterating after a pre-determined amount of time."
type TimeLimit <: LearningStrategy
    secs::Float64
    secs_end::Float64
    TimeLimit(secs::Number) = new(secs)
end
pre_hook(strat::TimeLimit, model) = (strat.secs_end = time() + strat.secs)
function finished(strat::TimeLimit, model, i)
    stop = time() >= strat.secs_end
    if stop
        info("Time's up!")
    end
    stop
end
```

This strategy has two fields: `secs` is used to initialize `secs_end` during the `pre_hook` callback, and `secs_end` is subsequently used to return true from `finished` when the time limit has been exceeded.

Additional built-in strategies can be found in [the code](https://github.com/JuliaML/LearningStrategies.jl/tree/master/src/strategies.jl).  More complex examples can be found in [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) and from [blog posts](http://www.breloff.com/JuliaML-and-Plots/).


# Acknowledgements
LearningStrategies is partially inspired by [IterationManagers](https://github.com/sglyon/IterationManagers.jl) and conversations with [Spencer Lyon](https://github.com/sglyon).  This functionality was previously part of the [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) package, but was split off as a dependency.

## Primary author: [Tom Breloff](https://github.com/tbreloff)
