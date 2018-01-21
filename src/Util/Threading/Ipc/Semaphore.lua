-- TODO: investigate why requiring socket anywhere (when using socket-lanes) causes to default to socket instead of socket-lanes

local NamedMutex = require "PuRest.Util.Threading.Ipc.NamedMutex"
local SharedStringValue = require "PuRest.Util.Threading.Ipc.SharedStringValue"
local sleep = require "PuRest.Util.Threading.sleep"
local Time = require "PuRest.Util.Chrono.Time"

local decrementErrorMessageTemplate = "attempted to decrement semaphore counter with id %s below 0"

local function Semaphore (name, parameters)
    local params = parameters or {}

    local id
    local limit

    local mutex
    local sharedCounter

    local function doCounterOperation(operation, isReadOnlyOperation)
        mutex.obtainLock()

        local rawCounterValue = sharedCounter.getValue()
        local counterValue = tonumber(rawCounterValue)
        
        if isReadOnlyOperation then
            operation(counterValue)
        else
            counterValue = operation(counterValue)
            sharedCounter.setValue(counterValue)
        end

        mutex.releaseLock()

        return counterValue
    end

    local function doReadOnlyCounterOperation(operation)
        return doCounterOperation(operation, true)
    end

    local function increment()
        local callerBlockedByLimit = limit > 0
        local counterValue

        repeat
            counterValue = doCounterOperation(function(counter)
                if callerBlockedByLimit then
                    callerBlockedByLimit = counter >= limit
                end

                return counter + 1
            end, not callerBlockedByLimit)

            if callerBlockedByLimit then
                sleep(0.01)
            end
        until not callerBlockedByLimit

        return counterValue
    end

    local function decrement()
        local triedToDecrementBelowZero = false

        local counterValue = doCounterOperation(function(counter)
            triedToDecrementBelowZero = counter < 1

            return triedToDecrementBelowZero and counter or counter - 1
        end)

        if triedToDecrementBelowZero then
            error(string.format(decrementErrorMessageTemplate, id))
        end

        return counterValue
    end

    local function getCounterValue()
        local counterValue

        doReadOnlyCounterOperation(function(counter)
            counterValue = counter
        end)

        return counterValue
    end

    local function getId()
        return id
    end

    local function getName()
        return name
    end

    local function construct()
        id = tostring(params.semaphoreId or Time.getTimeNowInMs())
        limit = params.semaphoreLimit or -1

        mutex = NamedMutex(name, (params.isOwner and params.isOwner or false))
        sharedCounter = SharedStringValue(id, 0)

        return
        {
            obtainLock = mutex.obtainLock,
            releaseLock = mutex.releaseLock,
            increment = increment,
            decrement = decrement,
            getCounterValue = getCounterValue,
            destroy = mutex.destroy,
            getId = getId,
            getName = getName
        }
    end

    return construct()
end

return Semaphore
