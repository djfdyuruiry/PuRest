local apr = require "apr"

local ServerConfig = require "PuRest.Config.resolveConfig"
local Site = require "PuRest.Server.Site"
local SiteCache = require "PuRest.Util.Cache.SiteCache"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Get the site that matches a location given in a HTTP request.
--
-- @param location The request location, e.g. '/site/resource/'
-- @return The matching site if found or nil.
--
local function getMatchingSite (location)
    validateParameters(
        {
            location = {location, Types._string_}
        }, "getMatchingSite")

    local siteLocation = location:match("/([^/]+)") or ""
    siteLocation = ServerConfig.siteNamesCaseSensitive and siteLocation or siteLocation:lower()

    if ServerConfig.enableSiteCache then
        local potentialCache = SiteCache.getSiteFromCache(siteLocation)

        if potentialCache then
            return potentialCache
        end
    end

    local path = string.format("%s/%s", ServerConfig.htmlDirectory, siteLocation):gsub("//", "/")

    local dirReader, error = apr.stat(path)

    if not dirReader or error then
        return
    end

    local site

    if dirReader.type == "directory" then
        local dirName = ServerConfig.siteNamesCaseSensitive and dirReader.name or dirReader.name:lower()

        if siteLocation == dirName then
            site = Site("http", dirReader.name, dirReader.path)
        end
    end

    if ServerConfig.enableSiteCache and site then
        SiteCache.setSiteInCache(location, site)
    end

    return site
end

return getMatchingSite