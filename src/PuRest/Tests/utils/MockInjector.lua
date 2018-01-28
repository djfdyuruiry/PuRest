local luaRequire = _G.require

local function injectMocks(mocks)
    _G.require = function(packageName)
        if mocks[packageName] then
            return mocks[packageName]
        end

        return luaRequire(packageName)    
    end
end

local function clearMocks()
    _G.require = luaRequire
end

return {
    injectMocks = injectMocks,
    clearMocks = clearMocks
}
