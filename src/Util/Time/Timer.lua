local apr = require "apr"

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
		local endTime = (apr.time_now() - startTime)
		return endTime * 1000
	end

    --- Start the timer by recording instantiation time.
    --
	local function construct ()
		startTime = apr.time_now()

		return
		{
			endTimeNow = endTimeNow
		}
	end

	return construct()
end

return Timer
