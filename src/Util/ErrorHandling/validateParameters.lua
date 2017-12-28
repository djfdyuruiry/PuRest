local getCallingFunctionInfo = require "PuRest.Util.Reflection.getCallingFunctionInfo"
local Types = require "PuRest.Util.ErrorHandling.Types"

--- Validate the parameters given to a function by performing type checking.
--
-- @param paramsDictionary Dictionary with entries in the format: name => {value, expectedType}.
-- @param funcName The name of the function calling for validation (NOT USED).
-- @param callingSelf Base case for validateParameters recursion.
--
local function validateParameters(paramsDictionary, _, callingSelf)
	if not callingSelf then
		validateParameters(
			{
				paramsDictionary = {paramsDictionary, Types._table_}
			},
			"validateParameters", true)
	end

    local callerInfo = getCallingFunctionInfo()

	for name, param in pairs(paramsDictionary) do
		-- Note: param = {value, expectedType}
		assert(type(param[1]) == param[2], string.format("bad argument '%s' to function '%s', excepted %s got %s", name,
                                                         callerInfo, param[2], type(param[1])))
	end
end

return validateParameters
