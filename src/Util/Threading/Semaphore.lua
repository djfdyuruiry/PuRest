local SharedValueStore = require "PuRest.Util.Threading.Ipc.SharedValueStore"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local decrementErrorMessageTemplate = "attempted to decrement semaphore counter with id %s below 0"

--- A lightweight Semaphore.
--
-- Call the object with no parameters to get value lock then pass
-- the new value back to release the lock.
--
-- e.x. Get value and hold lock: value = object()
--      Set value and release lock: object(value)
--
-- @param semaphoreId optional Id of existing semaphore to attach to.
-- @param initalValue optional The inital value of the semaphore.
-- @param isBinarySemaphore optional Should this semaphore only hold one value?
--                                   (Not a restriction just a flag)
--
local function Semaphore (name, isOwner, concurrencyLimit, id, initalValue)
	local sharedValueStore = SharedValueStore(name, 
	{
		semaphoreId = id,
		semaphoreLimit = concurrencyLimit,
		isOwner = isOwner
	})
	
	local binarySemaphore = concurrencyLimit == 1
	local holdingLock = false
	local lastPoppedValue
	
	local function getSemaphoreHandle ()
		return sharedValueStore
	end
	
	local function isBinarySemaphore ()
		return binarySemaphore
	end
	
	local function isHoldingLock ()
		if not binarySemaphore then
			error("You can only check resource locks for binary semaphores.")
		end

		return holdingLock
	end

	local function getValue ()
		local value = sharedValueStore.getValue(name, binarySemaphore)

		lastPoppedValue = value

		if binarySemaphore then
			holdingLock = true
		end

		return value
	end

	local function setValue (value)
		sharedValueStore.setValue(name, (value or lastPoppedValue), binarySemaphore)
		lastPoppedValue = nil

		if binarySemaphore then
			holdingLock = false
		end
	end
	
	local function getOrSetValue (_, value)
		if not value and not lastPoppedValue then
			return getValue()
		end

		setValue(value)
	end
	
	if initalValue then
		sharedValueStore.setValue(name, initalValue, false)
	end

	return setmetatable(
		{
			getThreadQueue = getSemaphoreHandle,
			init = sharedValueStore.init,
			isBinarySemaphore = isBinarySemaphore,
			isHoldingLock = isHoldingLock,
			getId = sharedValueStore.getId
		},
		{
			__call = getOrSetValue
		})
end

return Semaphore
