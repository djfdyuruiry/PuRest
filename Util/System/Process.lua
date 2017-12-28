local apr = require "apr"

local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local READ_TIMEOUT_MS = 100

--- Build up arguments for a process and execute it with pipes for
-- standard out/error.
--
-- @param path Path to the process binary.
-- @param humanReadableName Readable version of the process name.
-- @param args optional Table of command line arguments to pass to the process,
--                      with each token on the command line being a sequenital element
--                      (You may need to escape double quotes for some arguments).
-- @param readTimeout Timeout for reading the standard out/error.
--
local function Process (path, humanReadableName, args, readTimeout)
	validateParameters(
		{
			path = {path, Types._string_},
			humanReadableName = {humanReadableName, Types._string_}
		}, "Process.construct")

	local readTimeout = readTimeout or READ_TIMEOUT_MS
	local humanReadableName = humanReadableName or path

    --- Read all data from a pipe stream.
    --
    -- @param stream Process pipe stream.
    -- @param streamType Type of stream "out" | "err".
    -- @return String containing all data read from the stream.
    --
	local function readStream (stream, streamType)
		local out = ""
		local line, readErr = stream:read()

		streamType = streamType:lower()

		while line do
			out = out .. line

			try(function ()
				line, readErr = stream:read(readTimeout)
			end)
			.catch( function (ex)
				line = nil

				if ex:match("attempt to use a closed file") then
					-- Ignore closed streams.
					readErr = nil
				else
					readErr = ex
				end
			end)
		end

		if not line and readErr then
			error(string.format("Error while reading from %s steam for '%s' -> %s.", streamType, humanReadableName,
				readErr or "unknown error"))
		end

		return out
	end

    --- Get a pipe stream for a given process.
    --
    -- @param process Process handle to use to get pipe stream.
    -- @param streamType Type of stream "out" | "err".
    -- @return A new stream handle for the pipe specified.
    --
	local function createStream(process, streamType)
		local stream, streamCreateErr

		streamType = streamType:lower()

		if streamType == "out" then
			stream, streamCreateErr = process:out_get()
		elseif streamType == "err" then
			stream, streamCreateErr = process:err_get()
		end

		if not stream then
			error(string.format("Failed to open %s steam for '%s' -> %s.", streamType, humanReadableName,
				streamCreateErr or "unknown error"))
		end

		return stream
	end

    --- Run the process handle with the arguments specified, this
    -- can only be called once. Error is thrown if there is an issue setting
    -- up the process or any output was written to standard err from the process.
    --
    -- @return A string containing all the output from process standard out.
    --
	local function run ()
		local proc, createErr = apr.proc_create(path)

		if not proc then
			error(string.format("Failed to open process for '%s' -> %s.", humanReadableName, createErr or "unknown error"))
		end

        local cmdStatus, cmdErr = proc:cmdtype_set("shellcmd/env")

        if not cmdStatus or cmdErr then
            error(string.format("Error setting command type for process %s: %s.", humanReadableName, cmdErr or "unknown error"))
        end

        local ioStatus, ioErr = proc:io_set("none", "parent-block", "parent-block")

        if not ioStatus or ioErr then
            error(string.format("Error setting I/O parameters for process %s: %s.", humanReadableName, ioErr or "unknown error"))
        end

        local execStatus, execErr = proc:exec(type(args) == Types._table_ and args or nil)

        if not execStatus or execErr then
            error(string.format("Error executing process %s: %s.", humanReadableName, execErr or "unknown error"))
        end

		local err = readStream(createStream(proc, "err"), "err")

		if err and err ~= "" then
			error(string.format("Process '%s' threw an error -> %s.", humanReadableName, err))
		end

		return readStream(createStream(proc, "out"), "out")
	end

	return
	{
		run = run
	}
end

return Process
