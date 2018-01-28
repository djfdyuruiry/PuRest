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
        
        if operation then
            counterValue = operation(counterValue)
        end

        local readOnlyOperation = false

        if isReadOnlyOperation then
            readOnlyOperation = isReadOnlyOperation()
        end

        if not readOnlyOperation then
            sharedCounter.setValue(counterValue)
        end

        mutex.releaseLock()

        return counterValue
    end

    local function doReadOnlyCounterOperation(operation)
        return doCounterOperation(operation, function() 
            return true 
        end)
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
            end, function()
                return callerBlockedByLimit
            end)

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
        sharedCounter = SharedStringValue(id, 0, params)

        return
        {
            obtainLock = mutex.obtainLock,
            releaseLock = mutex.releaseLock,
            increment = increment,
            decrement = decrement,
            getCounterValue = doReadOnlyCounterOperation,
            destroy = mutex.destroy,
            getId = getId,
            getName = getName
        }
    end

    return construct()
end

return Semaphore
