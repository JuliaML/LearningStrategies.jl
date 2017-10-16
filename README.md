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

For a `MetaStrategy`, each function (`setup!`, `update!`, `hook`, `finished`, `cleanup!`) is mapped to the contained strategies.

## Examples

### Learning with a single LearningStrategy

```julia
julia> using LearningStrategies

julia> s = Verbose(TimeLimit(2))
Verbose TimeLimit(2.0)

julia> learn!(nothing, s)
INFO: TimeLimit(2.0) finished

julia> @elapsed learn!(nothing, s)
INFO: TimeLimit(2.0) finished
2.000225545
```

### Learning with a MetaLearner

```julia
julia> using LearningStrategies

julia> s = strategy(Verbose(MaxIter(5)), TimeLimit(10))
MetaStrategy
  > Verbose MaxIter(5)
  > TimeLimit(10.0)

julia> learn!(nothing, s, 1:100)
INFO: MaxIter(5) finished
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

Additional built-in strategies can be found in [the code](https://github.com/JuliaML/LearningStrategies.jl/tree/master/src/strategies.jl).  


# Acknowledgements
LearningStrategies is partially inspired by [IterationManagers](https://github.com/sglyon/IterationManagers.jl) and conversations with [Spencer Lyon](https://github.com/sglyon).  This functionality was previously part of the [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) package, but was split off as a dependency.

Complex LearningStrategy examples can be found in [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) and from [blog posts](http://www.breloff.com/JuliaML-and-Plots/).

## Primary author: [Tom Breloff](https://github.com/tbreloff)
