---@class ModController
ModController = {}

ModController.name = g_currentModName
ModController.path = g_currentModDirectory
ModController.globalKey = "EMPLOYEE_MANAGER_CONTROLLER"

local mod = g_modManager:getModByName(g_currentModName)
if mod ~= nil then
    ModController.version = mod.version
else
    ModController.version = "UNKNOWN"
    CustomUtils:error("[ModController] Could not get mod info for '%s'", g_currentModName)
end

ModController.isInitialized = false

---@param self table
---@param name string
---@param itemSystem table
---@param missionInfo table
---@param missionDynamicInfo table
---@param savegame table
function ModController:loadMap(name, itemSystem, missionInfo, missionDynamicInfo, savegame)
    CustomUtils:info("[%s] Loaded mod version %s", self.name, tostring(self.version))

    self.isInitialized = true

    CustomUtils:info("Initializing Employee Manager Mod...")

    g_employeeManager = EmployeeManager:new(g_currentMission)
    
    -- Initialize HUD
    if SimpleStatusHUD then
        self.hud = SimpleStatusHUD.new()
        self.hud:load()
        addConsoleCommand("emToggleHUD", "Toggles the Employee Manager Status HUD", "consoleToggleHUD", self)
    end
    
    -- Call mission initialization logic (registers commands, events, etc.)
    g_employeeManager:onMissionInitialize(self.path)

    -- Handle savegame loading
    if savegame ~= nil then
        local xmlFile = savegame.xmlFile
        local key = savegame.key .. ".FS25_EmployeeManager"
        if xmlFile:hasProperty(key) then
            g_employeeManager:loadFromXMLFile(xmlFile, key)
        end
    end

    -- For testing: generate 5 employees if list is still empty
    if #g_employeeManager.employees == 0 then
        for i = 1, 5 do
            g_employeeManager:generateRandomEmployee()
        end
    end

    -- Initialize and load GUI elements via ModGui (if available)
    if rawget(_G, 'g_modGui') ~= nil then
        g_modGui:onMapLoaded()
    end
end

function ModController:onSavegameSave(savegame)
    if g_employeeManager ~= nil and savegame ~= nil then
        local xmlFile = savegame.xmlFile
        local key = savegame.key .. ".FS25_EmployeeManager"
        g_employeeManager:saveToXMLFile(xmlFile, key)
    end
end

function ModController:deleteMap()
    if g_employeeManager then
        g_employeeManager = nil
    end
end

function ModController:update(dt)
    if g_employeeManager then
        g_employeeManager:update(dt)
    end
end

function ModController:draw()
    if self.hud and g_gui.currentGuiName == nil then
        self.hud:draw()
    end
end

function ModController:consoleToggleHUD()
    if self.hud then
        self.hud:toggle()
        return "HUD visibility toggled"
    end
    return "HUD not available"
end

function ModController:keyEvent(unicode, sym, modifier, isDown)
end

addModEventListener(ModController)
