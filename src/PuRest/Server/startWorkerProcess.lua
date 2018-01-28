
local log = require "PuRest.Logging.FileLogger"
local Process = require "PuRest.Util.System.Process"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local function startWorkerProcess(params)
	validateParameters(
		{
			params_threadId = {params.threadId, Types._string_},
			params_workerProcessSemaphoreId = {params.workerProcessSemaphoreId, Types._string_},
			params_sessionThreadSemaphoreId = {params.sessionThreadSemaphoreId, Types._string_},
			params_clientSocketFd = {params.clientSocketFd, Types._number_},
			params_useHttps = {params.useHttps, Types._boolean_},
			params_outputVariables = {params.outputVariables, Types._table_, isOptional = true}
        })

    log("startWorkerProcess")
    local luaParams = string.format("[[%s]], [[%s]], [[%s]], %f, %s, nil", 
        params.threadId, 
        params.workerProcessSemaphoreId,
        params.sessionThreadSemaphoreId, 
        params.clientSocketFd, 
        tostring(params.useHttps))
        
    log(string.format("lua params: %s", luaParams))
    local luaCode = string.format("(require 'PuRest.Server.processServerPointEntryPoint')(%s)", luaParams)

    log(string.format("lua code: %s", luaCode))
	local workerProcess = Process("lua", "processServerStateProcess", {
		"-e",
        string.format([["%s"]], luaCode)
    })
    
    log("runFork")
    workerProcess.runFork()
end

return startWorkerProcess