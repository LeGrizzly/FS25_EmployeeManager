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

    if SimpleStatusHUD then
        self.hud = SimpleStatusHUD.new()
        self.hud:load()
        addConsoleCommand("emToggleHUD", "Toggles the Employee Manager Status HUD", "consoleToggleHUD", self)
        addConsoleCommand("emMenuWorkflow", "Opens the Workflow Editor Menu", "consoleMenuWorkflow", self)
    end

    g_employeeManager:onMissionInitialize(self.path)

    if #g_employeeManager.employees == 0 then
        CustomUtils:info("Employee list empty, generating test employees...")
        for i = 1, 5 do
            g_employeeManager:generateRandomEmployee()
        end
    end

    if rawget(_G, 'g_modGui') ~= nil then
        g_modGui:onMapLoaded()
    end

    local _, eventId = g_inputBinding:registerActionEvent('EM_OPEN_WORKFLOW', self, self.onOpenWorkflow, false, true, false, true)
    if eventId then
        g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_EM_OPEN_WORKFLOW"))
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
        self.workflowActionEventId = eventId
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
    if self.workflowActionEventId then
        g_inputBinding:removeActionEvent(self.workflowActionEventId)
        self.workflowActionEventId = nil
    end

    if g_employeeManager then
        g_employeeManager = nil
    end
end

function ModController:update(dt)
    if g_employeeManager and g_employeeManager.update then
        g_employeeManager:update(dt)
    end
end

function ModController:onOpenWorkflow(actionName, inputValue)
    if g_gui.currentGuiName == nil and g_employeeManager ~= nil then
        self:openWorkflowTab()
    end
end

function ModController:consoleMenuWorkflow()
    if g_employeeManager == nil then
        return "Employee Manager not initialized"
    end
    self:openWorkflowTab()
    return "Opening Workflow Editor..."
end

function ModController:openWorkflowTab()
    if g_emGui == nil then
        CustomUtils:warning("[ModController] EMGui not loaded")
        return
    end
    g_gui:showGui("EMGui")
    if g_emGui.pagingElement ~= nil then
        g_emGui.pagingElement:setPage(2)
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
