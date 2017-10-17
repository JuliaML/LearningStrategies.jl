# LearningStrategies
| Master Build | Test Coverage | Discussion |
|--------------|---------------|------------|
| [![Build Status](https://travis-ci.org/JuliaML/LearningStrategies.jl.svg?branch=master)](https://travis-ci.org/JuliaML/LearningStrategies.jl) | [![codecov](https://codecov.io/gh/JuliaML/LearningStrategies.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaML/LearningStrategies.jl) | [![Gitter chat](https://badges.gitter.im/JuliaML/chat.svg)](https://gitter.im/JuliaML/chat) |

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

For a `MetaStrategy`, each function (`setup!`, `update!`, `hook`, `finished`, `cleanup!`) is mapped to the contained strategies.  The entire dataset can be included in the inner loop (`item == data`) by passing the argument `Offline(data)`.

## Built In Strategies

See help (i.e. `?MaxIter`) for more info.

- `MetaStrategy`
- `MaxIter`
- `TimeLimit`
- `Converged`
- `ConvergedTo`
- `IterFunction`
- `Tracer`
- `Breaker`
- `Verbose`

## Examples

### Learning with a single LearningStrategy

```julia
julia> using LearningStrategies

julia> s = Verbose(TimeLimit(2))
Verbose TimeLimit(2.0)

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


# Acknowledgements
LearningStrategies is partially inspired by [IterationManagers](https://github.com/sglyon/IterationManagers.jl) and conversations with [Spencer Lyon](https://github.com/sglyon).  This functionality was previously part of the [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) package, but was split off as a dependency.

Complex LearningStrategy examples can be found in [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) and from Tom Breloff's [blog posts](http://www.breloff.com/JuliaML-and-Plots/).

## Primary author: [Tom Breloff](https://github.com/tbreloff)
