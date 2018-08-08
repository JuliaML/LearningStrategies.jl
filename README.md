# LearningStrategies
| Master Build | Test Coverage | Discussion |
|--------------|---------------|------------|
| [![Build Status](https://travis-ci.org/JuliaML/LearningStrategies.jl.svg?branch=master)](https://travis-ci.org/JuliaML/LearningStrategies.jl) [![Build status](https://ci.appveyor.com/api/projects/status/ev39pu54fh4x2utl?svg=true)](https://ci.appveyor.com/project/joshday/learningstrategies-jl) | [![codecov](https://codecov.io/gh/JuliaML/LearningStrategies.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaML/LearningStrategies.jl) | [![Gitter chat](https://badges.gitter.im/JuliaML/chat.svg)](https://gitter.im/JuliaML/chat) |

**LearningStrategies is a modular framework for building iterative algorithms in Julia**.

Below, some of the key concepts are briefly explained, and a few examples are made. A more in-depth notebook can be found [here](http://nbviewer.jupyter.org/github/dominusmi/warwick-rsg/blob/master/Educational/LearningStrategies.ipynb)

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
The core function of LearningStrategies is a straightforward abstract implementation
of the above loop.  A `model` can be learned by an `LearningStrategy` or a collection of
strategies in a `MetaStrategy`.

```julia
function learn!(model, strat::LearningStrategy, data)
    setup!(strat, model[, data])
    for (i, item) in enumerate(data)
        update!(model, strat[, i], item)
        hook(strat, model[, data], i)
        finished(strat, model[, data], i) && break
    end
    cleanup!(strat, model)
    model
end
```

- For a `MetaStrategy`, each function (`setup!`, `update!`, `hook`, `finished`, `cleanup!`) is mapped to the contained strategies.
- To let `item == data`, pass the argument `Iterators.repeated(data)`.

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

julia> @elapsed learn!(nothing, s)  # data == InfiniteNothing()
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
INFO: MaxIter: 1/5
INFO: MaxIter: 2/5
INFO: MaxIter: 3/5
INFO: MaxIter: 4/5
INFO: MaxIter: 5/5
INFO: MaxIter(5) finished
```

### Linear Regression Solver

```julia
using LearningStrategies
import LearningStrategies: update!, finished
import Base.Iterators: repeated

struct MyLinearModel
    coef
end

struct MyLinearModelSolver <: LearningStrategy end

update!(model, s::MyLinearModelSolver, xy) = (model.coef[:] = xy[1] \ xy[2])

finished(s::MyLinearModelSolver, model) = true

# generate some fake data
x = randn(100, 5)
y = x * range(-1, stop=1, length=5) + randn(100)

data = (x, y)

# Create the model
model = MyLinearModel(zeros(5))

# learn! the model with data (x, y)
learn!(model, MyLinearModelSolver(), repeated(data))

# check that it works
model.coef == x \ y
```

### More Examples

There are some user contributed snippets in the `examples` dir.

- `dftracer.jl` shows a tracer with DataFrame as underlying storage.


# Acknowledgements
LearningStrategies is partially inspired by [IterationManagers](https://github.com/sglyon/IterationManagers.jl) and (Tom Breloff's) conversations with [Spencer Lyon](https://github.com/sglyon).  This functionality was previously part of the [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) package, but was split off as a dependency.

Complex LearningStrategy examples (using previous LearningStrategies versions) can be found in [StochasticOptimization](https://github.com/JuliaML/StochasticOptimization.jl) and from Tom Breloff's [blog posts](http://www.breloff.com/JuliaML-and-Plots/).

Examples using the current version can be found in [SparseRegression](https://github.com/joshday/SparseRegression.jl).

## Primary author: [Tom Breloff](https://github.com/tbreloff)
