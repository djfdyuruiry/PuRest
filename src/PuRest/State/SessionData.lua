local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local getSession = require "PuRest.State.getSession"
local setSessionData = require "PuRest.State.setSession"
local SharedValueStore = require "PuRest.Util.Threading.Ipc.SharedValueStore"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local sessionsStoreName = "purest_sessions"
local sessionDataKey = "sessions"

--- Sessions store to share sessions across
-- workers on server.
local sessionsSharedStore

--- Get the underlying id for the sessions store store.
--
-- @return The session store id.
--
local function getSemaphoreId ()
	if not sessionsSharedStore then
		sessionsSharedStore = SharedValueStore(sessionsStoreName, 
			{
				isOwner = true,
				semaphoreLimit = 1, 
				initalData =
				{
					sessions = 	
					{
						clientSessions = {},
						userAgentSessions = {}
					}
				}
			})
	end

	return sessionsSharedStore.getId()
end

--- Set the id to be used by the sessions store.
--
-- @param semaphoreId Id of the sessions store.
--
local function setSemaphoreId (semaphoreId)
	validateParameters(
		{
			semaphoreId = {semaphoreId, Types._string_}
		})

		sessionsSharedStore = SharedValueStore(sessionsStoreName, 
			{
				isOwner = false, 
				semaphoreId = semaphoreId, 
				semaphoreLimit = 1
			})
end

--- Create a formatted session id for user agent based session.
--
-- @param clientPeerName Client host name.
-- @param userAgent Client user agent string.
-- @return A plain text identifer for a user agent session.
--
local function createUserAgentId (clientPeerName, userAgent)
	return string.format("%s:%s", clientPeerName, userAgent)
end

--- Create a formatted session id for a peer name based session.
--
-- @param clientPeerName Client host name.
-- @param clientPort Client port.
-- @return A plain text identifer for a peer name session.
--
local function createPeerNameId(clientPeerName, clientPort)
	return string.format("%s:%s", clientPeerName, clientPort)
end

--- Resolves the session data for a request by user agent/peer name values.
-- Site config is used to determine supported session types and if a user
-- agent string is present and user sessions are enabled it is used over a peer
-- name session.
--
-- @param userAgent optional Client user agent string.
-- @param clientPeerName Client peer name / host.
-- @param clientPort Client port.
-- @param siteConfig Config for site requesting session data.
-- @return Session data table and ID for session in sessions store.
--
local function resolveSessionData (userAgent, clientPeerName, clientPort, siteConfig)
	validateParameters(
		{
			clientPeerName = {clientPeerName, Types._string_},
            clientPort = {clientPort, Types._string_},
			siteConfig = {siteConfig, Types._table_}
		})
	
	log("resolveSessionData", LogLevelMap.INFO)

	local sessions = sessionsSharedStore.getValueAndLock(sessionDataKey)
	local clientSessionData, sessionId

	local sessionsEnabled = siteConfig.sessions.peerNameSessionsEnabled
	local userSessionsEnabled = siteConfig.sessions.userAgentSessionsEnabled

	if userSessionsEnabled and userAgent then
		clientSessionData, sessionId = getSession(sessions, createUserAgentId(clientPeerName, userAgent), siteConfig, true)
	elseif sessionsEnabled then
		clientSessionData, sessionId = getSession(sessions, createPeerNameId(clientPeerName, clientPort), siteConfig, false)
	end

	sessionsSharedStore.setValueAndUnlock(sessionDataKey, sessions)
    --TODO: Investigate potential issue with session being requested by two threads and result not being merged, but second one to call perserve gets data written.

	return clientSessionData, sessionId
end

--- Perserve the session data for a request by user agent/peer name values.
-- Site config is used to determine supported session types and if a user
-- agent string is present and user sessions are enabled it is used over a peer
-- name session.
--
-- @param sessionData Session data table.
-- @param userAgent optional Client user agent string.
-- @param clientPeerName Client peer name / host.
-- @param clientPort Client port.
-- @param siteConfig Config for site requesting session data.
--
local function preserveSessionData (sessionData, userAgent, clientPeerName, clientPort, siteConfig)
	validateParameters(
		{
			sessionData = {sessionData, Types._table_},
			clientPeerName = {clientPeerName, Types._string_},
            clientPort = {clientPort, Types._string_},
			siteConfig = {siteConfig, Types._table_}
		})

	log("preserveSessionData", LogLevelMap.INFO)

	local sessions = sessionsSharedStore.getValueAndLock(sessionDataKey)
	local sessionsEnabled = siteConfig.sessions.peerNameSessionsEnabled
	local userSessionsEnabled = siteConfig.sessions.userAgentSessionsEnabled

	if userSessionsEnabled and userAgent then
		setSessionData(sessions, sessionData, createUserAgentId(clientPeerName, userAgent), siteConfig, true)
	elseif sessionsEnabled then
		setSessionData(sessions, sessionData, createPeerNameId(clientPeerName, clientPort), siteConfig, false)
	end

	sessionsSharedStore.setValueAndUnlock(sessionDataKey, sessions)
end

return
{
	getSemaphoreId = getSemaphoreId,
	setSemaphoreId = setSemaphoreId,
	resolveSessionData = resolveSessionData,
	preserveSessionData = preserveSessionData
}
