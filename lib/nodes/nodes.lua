local _PACKAGE           = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?nodes", "")

local Task               = require(_PACKAGE .. '/node_types/node')
local Decorator          = require(_PACKAGE .. '/node_types/decorator')
local RepeaterDecorator  = require(_PACKAGE .. '/node_types/repeater_decorator')
local InterruptDecorator = require(_PACKAGE .. '/node_types/interrupt_decorator')
local g                  = _BehaviourTreeGlobals


local function RunRandomWeight(config)
    local p = config.properties

    return Decorator:new(config)
end

local function RandomThrough(config)
    local p = config.properties

    config.start = function(task, state)
        if math.random() * 100 > p.probability() then
            task:fail()
        end
    end

    return Decorator:new(config)
end

local function StateCondition(config)
    local p = config.properties

    config.start = function(task, state)
        if not p.condition() then
            task:fail()
        end
    end

    return Decorator:new(config)
end

local function StateInterrupt(config)
    local p = config.properties

    config.shouldRun = function(task, state)
        return p.condition()
    end

    return InterruptDecorator:new(config)
end

local function ContinuousStateCondition(config)
    local p = config.properties

    -- Will not be ignored by branch nodes (Sequence, Priority e.t.c), branch node will be able to trigger it as any other regular node.
    config.isStealthy = false

    config.shouldRun = function(task, state)
        if not task.started then return false end
        -- Only interrupt itself, and only when condition is false
        return p.condition()
    end

    config.start = function(task, state)
        if not p.condition() then
            task:fail()
        else
            task.started = true
        end
    end

    config.finish = function(task, state)
        task.started = false
    end

    return InterruptDecorator:new(config)
end


local function LimitRunTime(config)
    local p = config.properties
    local timer = config.clock or g.clock

    config.isStealthy = false

    config.start = function(task, state)
        task.duration = p.duration()
        if type(task.duration) ~= "number" then
            error("duration() provided to LimitRunTime does not return a number. Return value type: " ..
                type(task.duration))
        end
        task.startedAt = timer()
        task.started = true
    end

    config.shouldRun = function(task, state)
        if not task.started then return false end
        return (timer() - task.startedAt) < task.duration
    end

    config.finish = function(task)
        task.started = false
    end

    return InterruptDecorator:new(config)
end


local function RepeatUntilSuccess(config)
    local p = config.properties
    config.untilSuccess = true
    -- Issue here is that maxLoop will be resolved only on init, instead of every start, which is not that good
    config.maxLoop = p.maxLoop()
    return RepeaterDecorator:new(config)
end


local function RepeatUntilFailure(config)
    local p = config.properties
    config.untilFailure = true
    config.maxLoop = p.maxLoop()
    return RepeaterDecorator:new(config)
end


local function Cooldown(config)
    -- Also - how can we add a cooldown for an interrupt, without triggering an interrup?
    local p = config.properties

    local timer = config.clock or g.clock
    local lastUseTime = nil
    local duration = nil


    config.start = function(task, state)
        if not duration then duration = p.duration() end

        local now = timer()
        task.gotThrough = false

        if not lastUseTime or now - lastUseTime > duration then
            lastUseTime = now
            duration = p.duration()
            task.gotThrough = true
        else
            return task:fail()
        end
    end

    config.finish = function(task, state)
        -- Rejecting is also finished, so this will be forever locked
        if task.gotThrough and p.hotWhileRunning() then
            lastUseTime = timer()
        end
    end

    return Decorator:new(config)
end


local function SetState(config)
    local p = config.properties

    config.start = function(task, state)
        for key, val in pairs(p) do
            state[key] = val()
        end
        return task:success()
    end

    return Task:new(config)
end


local function Succeeder(config)
    config.run = function(task, state)
        task:success()
    end
    return Task:new(config)
end


local function Failer(config)
    config.run = function(task, state)
        task:fail()
    end
    return Task:new(config)
end

function RandomSuccess(config)
    local props = config.properties

    -- this probably should be on start, not on run
    config.run = function(task, state)
        local roll = math.random() * 100
        if props.probability() > roll then
            task:success()
        else
            task:fail()
        end
    end

    return Task:new(config)
end

local function Runner(config)
    config.run = function(task, state)
        task:running()
    end
    return Task:new(config)
end

local function Wait(config)
    local p = config.properties
    local timer = config.clock or g.clock

    config.start = function(t, state)
        t.duration = p.duration()
        t.startTime = timer()
    end

    config.run = function(t, state)
        local now = timer()
        if now - t.startTime > t.duration then
            t:success()
        else
            t:running()
        end
    end

    return Task:new(config)
end


local function registerPremadeNodes(reg)
    reg.register("RunRandomWeight", RunRandomWeight)
    reg.register("RandomThrough", RandomThrough)
    reg.register("StateCondition", StateCondition)
    reg.register("StateInterrupt", StateInterrupt)
    reg.register("ContinuousStateCondition", ContinuousStateCondition)
    reg.register("LimitRunTime", LimitRunTime)
    reg.register('RepeatUntilFailure', RepeatUntilFailure)
    reg.register('RepeatUntilSuccess', RepeatUntilSuccess)
    reg.register("Cooldown", Cooldown)
    reg.register("SetState", SetState)
    reg.register("Succeeder", Succeeder)
    reg.register("Failer", Failer)
    reg.register("RandomSuccess", RandomSuccess)
    reg.register("Runner", Runner)
    reg.register("Wait", Wait)
end

return registerPremadeNodes
