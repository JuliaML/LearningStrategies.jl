using LearningStrategy
using DataFrames

import LearningStrategy: hook

struct DFTracer <: LearningStrategy
  f
  b::Int
  df::DataFrame

  DFTracer(T::Vector{<:Type}, names::Vector{Symbol}, f, b = 1) =
    new(f, b, DataFrame(T, names, 0))
end

function hook(t::DFTracer, m, i)
  (mod1(i, t.b) == t.b) && push!(t.df, t.f(m, i))
  nothing
end

dftracer = DFTracer([Float64, Symbol], [:reward, :action], (x, i) -> begin
  # ...
  (42, :magic)
end)
