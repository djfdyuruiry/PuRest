local luaSocket = require "socket"

local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local function convertClientSocketFileDescriptorToHttpDataPipe (fileDescriptor)
    validateParameters(
        {
            fileDescriptor = {fileDescriptor, Types._number_}
		}, "convertFileDescriptorToHttpDataPipe")

	local socket = luaSocket.tcp()
	
	-- hack to mark this socket as a client, instead of the default of master
	pcall(function() 
		socket:connect("*", 0)
	end)

	socket:setfd(fileDescriptor)

	return HttpDataPipe({socket = socket})
end

return convertClientSocketFileDescriptorToHttpDataPipe