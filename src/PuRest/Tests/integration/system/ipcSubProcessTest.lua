local luaPrint = print

local json = require "rxi-json-lua"

local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"
local SharedValueStore = require "PuRest.Util.Threading.Ipc.SharedValueStore"

local function print (...)
    luaPrint("ipc poc sub process test -> ", ...)
end

local function printCounterVal (op, counterVal)
    print(op, " semaphore | counter value = ", counterVal)
end

local function printSvsOp (op, ...)
    print("SharedValueStore op ", op, " result: " , ...)
end

status, err = pcall(function()
    print("--SharedValueStore subprocess test--")

    local svs_alt = SharedValueStore("svs", {semaphoreId = SVS_ID})

    printSvsOp("get subprocess", svs_alt.getValue("session0"))

    local session0 = svs_alt.getValueAndLock("session0")

    printSvsOp("get subprocess", json.encode(session0))

    session0.subprocessShouldDeleteThis = nil

    printSvsOp("set subprocess", svs_alt.setValueAndUnlock("session0", session0))

    printSvsOp("get subprocess", svs_alt.getValue("session0"))
    printSvsOp("get subprocess", json.encode(svs_alt.getValue("session0")))

    local status, err = pcall(svs_alt.destroy)
    
    print("destroy subprocess SharedValueStore result: ", status, err)
end)

print(status and "SharedValueStore subprocess test finished" or "SharedValueStore subprocess test error: ", err)
