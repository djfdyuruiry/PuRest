local luaPrint = print

local json = require "rxi-json-lua"

local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"
local SharedValueStore = require "PuRest.Util.Threading.Ipc.SharedValueStore"

local function print (...)
    luaPrint("ipc poc test -> ", ...)
end

local function printCounterVal (op, counterVal)
    print(op, " semaphore | counter value = ", counterVal)
end

local function printSvsOp (op, ...)
    print("SharedValueStore op ", op, " result: " , ...)
end

local status, err = pcall(function()
    print("--Semaphore test--")

    local sem = Semaphore("some_semaphore", {isOwner = true})

    printCounterVal("get", sem.getCounterValue())

    printCounterVal("increment", sem.increment())
    printCounterVal("increment", sem.increment())    
    printCounterVal("decrement", sem.decrement())
    printCounterVal("decrement", sem.decrement())

    local _, err = pcall(sem.decrement)

    print("decrement error test: ", err)

    printCounterVal("get", sem.getCounterValue())

    print("--Semaphore secondary instance test--")

    local sem_alt = Semaphore("some_semaphore", {semaphoreId = sem.getId()})
    
    printCounterVal("increment main", sem.increment())  
    
    printCounterVal("get alt", sem_alt.getCounterValue())
    
    printCounterVal("decrement alt", sem_alt.decrement())
    
    local status, err = pcall(sem_alt.destroy)
    
    print("destroy alt Semaphore result: ", status, err)

    print("destroy Semaphore result: ", sem.destroy())

    local status, err = pcall(sem.getCounterValue)

    print("get after destroy result: ", status, err)

    local status, err = pcall(sem_alt.getCounterValue)

    print("get alt after destroy result: ", status, err)

    local status, err = pcall(sem_alt.getCounterValue)

    print("2nd get alt after destroy result: ", status, err)
end)

print(status and "Semaphore test finished" or "Semaphore test error: ", err)

status, err = pcall(function()
    print("--SharedValueStore test--")

    local svs = SharedValueStore("svs", {isOwner = true})

    printSvsOp("set", svs.setValue("session0", {id=92839,username="ezra"}))

    local session0, key, valueWasSet = svs.getValueAndLock("session0")

    printSvsOp("get", session0, key, valueWasSet)
    printSvsOp("get", json.encode(svs.getValueAndLock("session0")))

    session0.id = session0.id + 2
    session0.extra_prop = "fefmnifnei"

    printSvsOp("set", svs.setValueAndUnlock("session0", session0))

    printSvsOp("get", svs.getValue("session0"))
    printSvsOp("get", json.encode(svs.getValue("session0")))

    print("--SharedValueStore secondary instance test--")

    local svs_alt = SharedValueStore("svs", {semaphoreId = svs.getId()})

    printSvsOp("get alt", svs_alt.getValue("session0"))
    printSvsOp("get alt", json.encode(svs_alt.getValueAndLock("session0")))

    session0.extra_prop = nil

    printSvsOp("set main", svs.setValueAndUnlock("session0", session0))

    printSvsOp("get alt", svs_alt.getValue("session0"))
    printSvsOp("get alt", json.encode(svs_alt.getValue("session0")))

    local status, err = pcall(svs_alt.destroy)
    
    print("destroy alt SharedValueStore result: ", status, err)

    print("destroy SharedValueStore result: ", svs.destroy())

    local status, err = pcall(svs.getValue)

    print("get after destroy result: ", status, err)

    local status, err = pcall(svs_alt.getValue)

    print("get alt after destroy result: ", status, err)

    local status, err = pcall(svs_alt.getValue)

    print("2nd get alt after destroy result: ", status, err)
end)

print(status and "SharedValueStore test finished" or "SharedValueStore test error: ", err)
