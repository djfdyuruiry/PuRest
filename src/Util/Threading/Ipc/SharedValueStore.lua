local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"
local Serialization = require "PuRest.Util.Data.Serialization"
local SharedStringValue = require "PuRest.Util.Threading.Ipc.SharedStringValue"
local Time = require "PuRest.Util.Chrono.Time"

local operationErrorMessageTemplate = "Error %sting value in shared store: %s"

local function SharedValueStore (name, parameters)
    local params = parameters

    local id

    local semaphore
    local keysSharedValue
    local valuesSharedValue

    local function doKeysOperation(operation, isReadOnlyOperation)
        local rawKeys = keysSharedValue.getValue()
        local keys = Serialization.parseJson(rawKeys)
        
        if isReadOnlyOperation then
            operation(keys)
        else
            operation(keys)

            local newRawKeys = Serialization.serializeToJson(keys)

            keysSharedValue.setValue(newRawKeys)
        end

        return keys
    end

    local function doReadOnlyKeysOperation(operation)
        return doKeysOperation(operation, true)
    end

    local function doValuesOperation(operation, isReadOnlyOperation)
        local rawValues = valuesSharedValue.getValue()
        local values = Serialization.parseJson(rawValues)
        
        if isReadOnlyOperation then
            operation(values)
        else
            operation(values)

            local newRawValues = Serialization.serializeToJson(values)

            valuesSharedValue.setValue(newRawValues)
        end

        return values
    end

    local function doReadOnlyValuesOperation(operation)
        return doValuesOperation(operation, true)
    end

    local function getValue(key, keepLocked)
        semaphore.increment()
        
        local value = nil
        local keyPresent = false

        local status, err = pcall(function()
            doReadOnlyKeysOperation(function(keys)
                keyPresent = keys[key]
            end)

            if keyPresent then
                doReadOnlyValuesOperation(function(values)
                    value = values[key]
                end)
            end
        end)

        if not keepLocked then
            semaphore.decrement()
        end

        if not status or err then
            error(string.format(operationErrorMessageTemplate, "get", err or "unknown error"))
        end

        return value, key, keyPresent
    end

    local function getValueAndLock(key)
        return getValue(key, true)
    end

    local function setValue(key, value, locked)
        if not locked then
            semaphore.increment()
        end

        local setExistingKey = false

        local status, err = pcall(function()
            doKeysOperation(function(keys)
                setExistingKey = keys[key] and true or false
                keys[key] = true
            end)
    
            doValuesOperation(function(values)
                values[key] = value
            end)
        end)

        semaphore.decrement()

        if not status or err then
            error(string.format(operationErrorMessageTemplate, "set", err or "unknown error"))
        end

        return value, key, setExistingKey
    end

    local function setValueAndUnlock(key, value)
        return setValue(key, value, true)
    end

    local function getId()
        return id
    end

    local function getName()
        return name
    end

    local function construct()
        id = tostring(params.semaphoreId or Time.getTimeNowInMs())
        semaphore = Semaphore(name, params)

        keysSharedValue = SharedStringValue(string.format("%s_keys", id), params.isOwner and "{}" or nil)
        valuesSharedValue = SharedStringValue(string.format("%s_values", id), params.isOwner and "{}" or nil)

        return
        {
            getValue = getValue,
            getValueAndLock = getValueAndLock,
            setValue = setValue,
            setValueAndUnlock = setValueAndUnlock,
            destroy = semaphore.destroy,
            getId = getId,
            getName = getName
        }
    end

    return construct()
end

return SharedValueStore
