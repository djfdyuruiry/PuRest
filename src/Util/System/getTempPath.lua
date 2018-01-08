local function getTempPath()
    local directorySeperator = package.config:match("([^\n]*)\n?")
    local exampleTempFilePath = os.tmpname()
    
    -- remove generated temp file
    pcall(os.remove, exampleTempFilePath)

    local seperatorIdx = exampleTempFilePath:reverse():find(directorySeperator)
    local tempPathStringLength = #exampleTempFilePath - seperatorIdx

    return exampleTempFilePath:sub(1, tempPathStringLength)
end

return getTempPath
