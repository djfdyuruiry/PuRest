local getSessionId = require "PuRest.State.getSessionId"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Timer = require "PuRest.Util.Chrono.Timer"
local try = require "PuRest.Util.ErrorHandling.try"
local Time = require "PuRest.Util.Chrono.Time"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Lookup a session in the sessions store using a session ID
-- and return it's data. Error is thrown if session has expired.
--
-- @param sessions Sessions store table.
-- @param sessionId MD5 hash Session identifier string; generated by getSessionId(..).
-- @param isUserAgent Is the session ID based on a user agent.
-- @return The data for the specified session.
--
local function lookupSession (sessions, sessionId, isUserAgent)
	validateParameters(
		{
            sessions = {sessions, Types._table_},
			sessionId = {sessionId, Types._string_},
			isUserAgent = {isUserAgent, Types._boolean_}
		},
		"getSessionData.lookupSession")

	local key = isUserAgent and "userAgentSessions" or "clientSessions"
	local session = sessions[key][sessionId]

	-- Check for session and create a new one if not found.
	if not session then
		sessions[key][sessionId] = {data = {}, id = sessionId}
		session = sessions[key][sessionId]
	end

	-- Check if current session has expired.
	if session.expiryEpochTime and Time.getTimeNowInSecs() >= tonumber(session.expiryEpochTime) then
		sessions[key][sessionId] = nil
		collectgarbage()

		error(string.format("Session with is '%s' has expired and has been deleted.", sessionId))
	end

	return session.data
end

--- Get the session data for a plain text session identifier from the sessions
-- store, respecting site config.
--
-- @param sessions Sessions store table.
-- @param sessionIdentifier Plain text session identifier.
-- @param siteConfig Config for the site requesting session data.
-- @param isUserAgent Is the session identifier user agent based.
-- @return The data for the specified session or nil if an error occurred
--         and the MD5 session ID hash, generated by getSessionId(..).
--
local function getSessionData (sessions, sessionIdentifier, siteConfig, isUserAgent)
	validateParameters(
		{
            sessions = {sessions, Types._table_},
			sessionIdentifier = {sessionIdentifier, Types._string_},
			siteConfig = {siteConfig, Types._table_},
			isUserAgent = {isUserAgent, Types._boolean_}
		}, "getSessionData")

	local timer = Timer()

	local sessionData
	local sessionId, plainSessionId = getSessionId(sessionIdentifier, siteConfig.name)

	try(function()
		sessionData = lookupSession(sessions, sessionId, isUserAgent)

		log(string.format("Loaded session with id '%s'.", sessionId), LogLevelMap.INFO)
		log(string.format("Getting session with id '%s' took %s ms.", sessionId, timer.endTimeNow()), LogLevelMap.DEBUG)
	end)
	.catch( function (ex)
		local logLevel = ex:match("has expired and has been deleted") and LogLevelMap.INFO or LogLevelMap.ERROR

		log(string.format("Failed to load session with id '%s': %s", sessionId, ex), logLevel)
		sessionData = nil
	end)

	log(string.format("Session id in plain text: '%s'.", plainSessionId), LogLevelMap.DEBUG)

	return sessionData, sessionId
end

return getSessionData
