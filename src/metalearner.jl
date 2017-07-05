#-----------------------------------------------------------------------# MetaLearner
"""
    MetaLearner(strats::LearningStrategy...)

A Meta-learner which joins learning strategies in a type-stable way.
"""
struct MetaLearner{MGRS <: Tuple} <: LearningStrategy
    managers::MGRS
end

function MetaLearner(mgrs::LearningStrategy...)
    MetaLearner(mgrs)
end

pre_hook(meta::MetaLearner,  model)     = foreach(mgr -> pre_hook(mgr, model),     meta.managers)
iter_hook(meta::MetaLearner, model, i)  = foreach(mgr -> iter_hook(mgr, model, i), meta.managers)
finished(meta::MetaLearner,  model, i)  = any(mgr     -> finished(mgr, model, i),  meta.managers)
post_hook(meta::MetaLearner, model)     = foreach(mgr -> post_hook(mgr, model),    meta.managers)
update!(model, meta::MetaLearner, item) = foreach(mgr -> update!(model, mgr, item), meta.managers)

# How data is sent to the metalearner
module LearnType
    struct Offline end
    struct Online  end
end

#-----------------------------------------------------------------------# Online
function learn!(model, meta::MetaLearner, data, ::LearnType.Online = LearnType.Online())
    pre_hook(meta, model)
    for (i, item) in enumerate(data)
        update!(model, meta, item)
        iter_hook(meta, model, i)
        finished(meta, model, i) && break
    end
    post_hook(meta, model)
end

#-----------------------------------------------------------------------# Offline
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


# return nothing forever
struct InfiniteNothing end
Base.start(itr::InfiniteNothing) = 1
Base.done(itr::InfiniteNothing, i) = false
Base.next(itr::InfiniteNothing, i) = (nothing, i+1)


# we can optionally learn without input data... good for minimizing functions
learn!(model, meta::MetaLearner) = learn!(model, meta, InfiniteNothing())

# TODO: can we instead use generated functions for each MetaLearner callback so that they are ONLY called for
#   those methods which the manager explicitly implements??  We'd need to have a type-stable way
#   of checking whether that manager implements that method.

# @generated function pre_hook(meta::MetaLearner, model)
#     body = quote end
#     mgr_types = meta.parameters[1]
#     for (i,T) in enumerate(mgr_types)
#         if is_implemented(T, :pre_hook)
#             push!(body.args, :(pre_hook(meta.managers[$i], model)))
#         end
#     end
#     body
# end

# -------------------------------------------------------------

function make_learner(args...; kw...)
    strats = []
    for (k,v) in kw
        if k == :maxiter
            push!(strats, MaxIter(v))
        elseif k == :oniter
            push!(strats, IterFunction(v))
        elseif k == :converged
            push!(strats, ConvergenceFunction(v))
        end
    end
    MetaLearner(args..., strats...)
end
