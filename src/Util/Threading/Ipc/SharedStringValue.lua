local ipcShm = require  "ipc.shm"

local set = "set"
local all = "*all"

local stringPackSeperator = "<"
local sharedStringValueSize = 2048

local function SharedStringValue(id, initalValue, parameters)
    local params = parameters    
    local shmHandle

    local function rewindShmHandle()
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
        rewindShmHandle()

        local rawValue = shmHandle:read(all)
        local value = unpackValueFromString(rawValue)
        
        return value
    end

    local function setValue(value)
        local newRawValue = packValueIntoString(value)

        rewindShmHandle()
        shmHandle:write(newRawValue)

        return newRawValue
    end

    local function getId()
        return id
    end

    local function construct()
        local createHandleStatus, createHandleError = pcall(function ()
            -- ensure shmHandle is initalised
            if params and params.isOwner then
                shmHandle, err = ipcShm.create(id, sharedStringValueSize)
            else
                shmHandle, err = ipcShm.attach(id)
            end

            if not shmHandle or err then
                error(err or "unknown error")
            end

            if initalValue then
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
