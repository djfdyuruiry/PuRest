local ipcShm = require "ipc.shm"

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"

local set = "set"
local all = "*all"

local stringPackSeperator = "§§§"
local sharedStringValueSize = 2048

local function SharedStringValue(id, initalValue, parameters)
    local params = parameters    
    local shmHandle

    local function rewindShmHandle()
        log(string.format("rewinding SharedStringValue shmHandle handle with id %s", id), LogLevelMap.DEBUG)
        shmHandle:seek(set, 0)
    end

    local function splitString(string, sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        
        string:gsub(pattern, function(value) 
            table.insert(fields, value) 
        end)
        
        return fields
    end

    local function unpackValueFromString(str)
        local stringParts = splitString(str, stringPackSeperator)
        return stringParts[1]
    end

    local function packValueIntoString(value)
        return string.format("%s%s%s", stringPackSeperator, tostring(value), stringPackSeperator)
    end

    local function getValue()
        log(string.format("attempting to read value from SharedStringValue with id %s", id), LogLevelMap.DEBUG)

        rewindShmHandle()

        local rawValue = shmHandle:read(all)
        local value = unpackValueFromString(rawValue)
        
        log(string.format("read value from SharedStringValue with id %s: rawValue - %s | value - %s", id, rawValue, value), LogLevelMap.DEBUG)

        return value
    end

    local function setValue(value)
        log(string.format("attempting to set value of SharedStringValue with id %s: value - %s", id, value), LogLevelMap.DEBUG)

        local newRawValue = packValueIntoString(value)

        rewindShmHandle()
        shmHandle:write(newRawValue)

        log(string.format("set value of SharedStringValue with id %s: value - %s | newRawValue: %s", id, value, newRawValue), LogLevelMap.DEBUG)

        return newRawValue
    end

    local function getId()
        return id
    end

    local function construct()
        local createHandleStatus, createHandleError = pcall(function ()
            -- ensure shmHandle is initalised
            if params and params.isOwner then
                log(string.format("Creating handle for SharedStringValue with id %s", id), LogLevelMap.DEBUG)
                shmHandle, err = ipcShm.create(id, sharedStringValueSize)
            else
                log(string.format("Attaching handle for SharedStringValue with id %s", id), LogLevelMap.DEBUG)
                shmHandle, err = ipcShm.attach(id)
            end

            if not shmHandle or err then
                error(err or "unknown error")
            end

            if initalValue and (params and params.isOwner) then
                log(string.format("Setting inital value for SharedStringValue with id %s", id), LogLevelMap.DEBUG)
                setValue(initalValue)
            end
        end)

        if not createHandleStatus or createHandleError then
            -- TODO: log this as debug
            -- print("Attempt to create handle failed: ", createHandleError)
            error(createHandleError or "unknown error creating or attaching shared memory handle")
        end

        return
        {
            getValue = getValue,
            setValue = setValue,
            getId = getId
        }
    end

    return construct()
end

return SharedStringValue
