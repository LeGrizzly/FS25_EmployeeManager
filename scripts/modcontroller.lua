---@class ModController
ModController = {}

ModController.name = g_currentModName
ModController.path = g_currentModDirectory
ModController.globalKey = "EMPLOYEE_MANAGER_CONTROLLER"
ModController.version = g_modManager:getModByName(g_currentModName).version

ModController.isInitialized = false

---@param self nil
function ModController:loadMap()
    Logging.info("[%s] Loaded mod version %s", self.name, tostring(self.version))

    self.isInitialized = true

    print("[FS25_EmployeeManager] Initializing Employee Manager Mod...")

    g_employeeManager = EmployeeManager:new(g_currentMission)

    -- For testing: generate 5 employees on map load
    for i = 1, 5 do
        g_employeeManager:generateRandomEmployee()
    end

    -- Initialize and load GUI elements via ModGui (if available)
    if rawget(_G, 'g_modGui') ~= nil then
        g_modGui:onMapLoaded()
    end
end

function ModController:deleteMap()
    -- Placeholder for any cleanup logic needed when the map is unloaded.
end

function ModController:keyEvent(unicode, sym, modifier, isDown)
end

function ModController:mouseEvent(posX, posY, isDown, isUp, button)
end

function ModController:draw()
end

addModEventListener(ModController)
