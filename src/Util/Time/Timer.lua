local luaSocket = require "socket-lanes"

local function getTimeNowInMs ()
	return luaSocket:gettime() * 1000
end

--- Profile timer to measure time in milliseconds between
-- Timer object created and call of endTimeNow().
--
-- e.x: local timer = Timer()
--      .. do stuff ..
--      local timeToDoStuff = timer.endTimeNow().
--
--
local function Timer ()
	local startTime

    --- Get the time in milliseconds between the
    -- construction of this Timer instance and now.
    -- (This can be called multiple times without side affect)
    --
    -- @return The time amount in milliseconds.
    --
	local function endTimeNow ()
		local endTime = (getTimeNowInMs() - startTime)
		return endTime
	end

    --- Start the timer by recording instantiation time.
    --
	local function construct ()
		startTime = getTimeNowInMs()

		return
		{
			endTimeNow = endTimeNow
		}
	end

	return construct()
end

return Timer
