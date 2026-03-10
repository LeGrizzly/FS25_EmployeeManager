XMLPersistence = {}
XMLPersistence.__index = XMLPersistence

function XMLPersistence:new()
    return setmetatable({}, self)
end

function XMLPersistence:getName()
    return "XML"
end

function XMLPersistence:isAvailable()
    return true
end

function XMLPersistence:getSavegameDirectory()
    if g_currentMission and g_currentMission.missionInfo then
        return g_currentMission.missionInfo.savegameDirectory
    end
    return nil
end

function XMLPersistence:save(employeeManager, parkingManager)
    local dir = self:getSavegameDirectory()
    if dir == nil then
        CustomUtils:warning("[XMLPersistence] No savegame directory, cannot save")
        return false
    end

    local xmlPath = dir .. "/employeeManager.xml"
    local xmlFile = createXMLFile("employeeManagerXML", xmlPath, "employeeManager")
    if xmlFile == nil or xmlFile == 0 then
        CustomUtils:error("[XMLPersistence] Failed to create save file: %s", xmlPath)
        return false
    end

    employeeManager:saveToXMLFile(xmlFile, "employeeManager")

    local fieldKey = "employeeManager.fieldConfigs"
    local fIdx = 0
    for fieldId, config in pairs(employeeManager.fieldConfigs or {}) do
        local base = string.format("%s.fieldConfig(%d)", fieldKey, fIdx)
        setXMLInt(xmlFile, base .. "#fieldId", fieldId)
        setXMLString(xmlFile, base .. "#cropName", config.cropName or "")
        fIdx = fIdx + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    local hiredCount = 0
    for _, e in ipairs(employeeManager.employees) do
        if e.isHired then hiredCount = hiredCount + 1 end
    end
    CustomUtils:info("[XMLPersistence] Saved %d employees (%d hired) to %s", #employeeManager.employees, hiredCount, xmlPath)
    return true
end

function XMLPersistence:load(employeeManager, parkingManager)
    local dir = self:getSavegameDirectory()
    if dir == nil then
        CustomUtils:warning("[XMLPersistence] No savegame directory available for loading")
        return false
    end

    local xmlPath = dir .. "/employeeManager.xml"
    if not fileExists(xmlPath) then
        CustomUtils:info("[XMLPersistence] No save file found at %s", xmlPath)
        return false
    end

    CustomUtils:info("[XMLPersistence] Loading from: %s", xmlPath)
    local xmlFile = loadXMLFile("employeeManagerXML", xmlPath)
    if xmlFile == nil or xmlFile == 0 then
        CustomUtils:error("[XMLPersistence] Failed to load file: %s", xmlPath)
        return false
    end

    employeeManager:loadFromXMLFile(xmlFile, "employeeManager")

    employeeManager.fieldConfigs = {}
    local fieldKey = "employeeManager.fieldConfigs"
    local fIdx = 0
    while true do
        local base = string.format("%s.fieldConfig(%d)", fieldKey, fIdx)
        local fId = getXMLInt(xmlFile, base .. "#fieldId")
        if not fId then break end
        local cName = getXMLString(xmlFile, base .. "#cropName")
        employeeManager.fieldConfigs[fId] = { cropName = cName }
        fIdx = fIdx + 1
    end

    delete(xmlFile)

    local hiredCount = 0
    for _, e in ipairs(employeeManager.employees) do
        if e.isHired then hiredCount = hiredCount + 1 end
    end
    CustomUtils:info("[XMLPersistence] Loaded %d employees (%d hired)", #employeeManager.employees, hiredCount)
    return #employeeManager.employees > 0
end
