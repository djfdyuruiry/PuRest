local apr = require "apr"

--- Provides a lightweight Semaphore built on a thread queue.
-- Call the object with no parameters to get value lock then pass
-- the new value back to release the lock.
--
-- e.x. Get value and hold lock: value = object()
--      Set value and release lock: object(value)
--
-- @param threadQueue optional An existing thread queue to use
-- @param initalValue optional The inital value to place in the thread queue.
-- @param isBinarySemaphore optional Should this semaphore only hold one value?
--                                   (Not a restriction just a flag)
--
local function Semaphore (threadQueue, initalValue, isBinarySemaphore)
	-- TODO: repalce with lanes (https://luarocks.org/modules/luarocks/lanes)
	local threadQueue = threadQueue or apr.thread_queue()
	local binarySemaphore = isBinarySemaphore or false
	local holdingLock = false
	local lastPoppedValue

	if initalValue then
		threadQueue:push(initalValue)
	end

    --- Get the thread queue being used by this semaphore.
    --
    -- @return The underlying thread queue.
    --
	local function getThreadQueue ()
		return threadQueue
	end

    --- Should this semaphore only hold one value?
    --  (Not a restriction just a flag)
    --
    -- @return True if only one value should be stored in
    --         this semaphore, otherwise false.
    --
	local function isBinarySemaphore ()
		return binarySemaphore
	end

    --- Is this semaphore instance holding the lock on a thread
    --  queue marked with the binary semaphore flag.
    --
    -- @return True if holding lock, false otherwise.
    --
	local function isHoldingLock ()
		if not binarySemaphore then
			error("You can only check resource locks for binary semaphores.")
		end

		return holdingLock
	end

	return setmetatable(
		{
			getThreadQueue = getThreadQueue,
			isBinarySemaphore = isBinarySemaphore,
			isHoldingLock = isHoldingLock
		},
		{
            --- Hold a lock and get the value or release a lock and set the value.
            -- If binary semaphore flag is on this also denotes if lock is held in
            -- holdingLock field.
            --
            -- @param value optional Value to push onto the queue.
            -- @return Nothing if releasing lock, value from front of queue otherwise.
            --
			__call = function (_, value)
				if value or lastPoppedValue then
					threadQueue:push(value or lastPoppedValue)
					lastPoppedValue = nil

					if binarySemaphore then
						holdingLock = false
					end
				else
					local val, err, errCode = threadQueue:pop()

					-- If pop method was interrupted it will need to be called again.
					while val == nil do
						val = threadQueue:pop()
					end

					lastPoppedValue = val

					if binarySemaphore then
						holdingLock = true
					end

					return val
				end
			end
		})
end

return Semaphore
