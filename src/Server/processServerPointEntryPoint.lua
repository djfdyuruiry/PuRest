local function processServerPointEntryPoint (threadId, workerProcessSemaphoreId, sessionSemaphoreId, clientSocketFd, useHttps)
	-- in new thread, need to get dependencies when executed instead of when included
	local log = require "PuRest.Logging.FileLogger"
	local LogLevelMap = require "PuRest.Logging.LogLevelMap"
	local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"
	local try = require "PuRest.Util.ErrorHandling.try"
	local Types = require "PuRest.Util.ErrorHandling.Types"
	local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

	-- Validate function parameters.
	validateParameters(
		{
			threadId = {threadId, Types._string_},
			workerProcessSemaphoreId = {workerProcessSemaphoreId, Types._string_},
			sessionSemaphoreId = {sessionSemaphoreId, Types._string_},
			clientSocketFd = {clientSocketFd, Types._number_},
			useHttps = {useHttps, Types._boolean_}
		}, "clientRequestThreadEntryPoint")

	local outputVariables = 
	{
		clientDataPipe = nil,
		peername = nil
	}

    local serverType = useHttps and "HTTPS" or "HTTP"
	local workerProcessSemaphore

	try(function() 
		local processServerState = require "PuRest.Server.processServerState"
		local ServerConfig = require "PuRest.Config.resolveConfig"

		workerProcessSemaphore = Semaphore(string.format("%s_workerProcess", serverType), 
			{
				isOwner = false, 
				semaphoreId = workerProcessSemaphoreId,
				limit = ServerConfig.workerThreads
			})
		
		processServerState(threadId, workerProcessSemaphoreId, sessionSemaphoreId, clientSocketFd, useHttps, outputVariables)
	end).
	catch(function(err)
		-- Detect any errors that occurred outside the main HTTP request loop.
		log(string.format("Error while running thread with id %s: %s", threadId, err), LogLevelMap.ERROR)

		if outputVariables.clientDataPipe then
			log(string.format("Attempting to close socket connection with client '%s' after error on thread with id %s",
				tostring(outputVariables.peername), threadId), LogLevelMap.INFO)
		
			pcall(clientDataPipe.terminate)
		end
	end).
	finally(function()
		pcall(workerProcessSemaphore.decrement)
	end)
end

return processServerPointEntryPoint