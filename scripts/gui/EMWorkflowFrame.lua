EMWorkflowFrame = {}

local EMWorkflowFrame_mt = Class(EMWorkflowFrame, TabbedMenuFrameElement)

EMWorkflowFrame.TASK_REQUIREMENTS = {
    SOW        = { skill = "driving",    level = 1 },
    ROLL       = { skill = "driving",    level = 1 },
    MULCH      = { skill = "driving",    level = 1 },
    CULTIVATE  = { skill = "driving",    level = 2 },
    RIDGING    = { skill = "driving",    level = 2 },
    PLOW       = { skill = "driving",    level = 3 },
    LIME       = { skill = "technical",  level = 1 },
    WEED       = { skill = "technical",  level = 1 },
    STONES     = { skill = "technical",  level = 1 },
    FERTILIZE  = { skill = "technical",  level = 2 },
    TEDDER     = { skill = "harvesting", level = 1 },
    MOW        = { skill = "harvesting", level = 2 },
    WINDROWER  = { skill = "harvesting", level = 2 },
    HARVEST    = { skill = "harvesting", level = 3 },
}

function EMWorkflowFrame:new()
    local self = TabbedMenuFrameElement.new(nil, EMWorkflowFrame_mt)

    self.availableTasksRenderer = TaskListItemRenderer.new(self)
    self.queueTasksRenderer     = TaskListItemRenderer.new(self)

    self.hiredEmployees = {}
    self.ownedFields    = {}
    self.ownedVehicles  = {}
    self.menuButtonInfo = {}

    return self
end

function EMWorkflowFrame:copyAttributes(src)
    EMWorkflowFrame:superClass().copyAttributes(self, src)
end

function EMWorkflowFrame:initialize()
    self.backButtonInfo = { inputAction = InputAction.MENU_BACK }
    self.saveButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_ACTIVATE,
        text        = g_i18n:getText("em_btn_save"),
        callback    = function() self:onSave() end,
    }
    self.saveStartButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_EXTRA_1,
        text        = g_i18n:getText("em_btn_save_start"),
        callback    = function() self:onSaveAndStart() end,
    }

    local hourTexts = {}
    for h = 0, 23 do
        table.insert(hourTexts, string.format("%02d:00", h))
    end
    if self.shiftStartSelector then
        self.shiftStartSelector:setTexts(hourTexts)
    end
    if self.shiftEndSelector then
        self.shiftEndSelector:setTexts(hourTexts)
    end
end

function EMWorkflowFrame:onGuiSetupFinished()
    EMWorkflowFrame:superClass().onGuiSetupFinished(self)

    self.employeeList:setDataSource(self)
    self.employeeList:setDelegate(self)

    if self.availableTasksList then
        self.availableTasksList:setDataSource(self.availableTasksRenderer)
        self.availableTasksList:setDelegate(self.availableTasksRenderer)
    end
    if self.queueList then
        self.queueList:setDataSource(self.queueTasksRenderer)
        self.queueList:setDelegate(self.queueTasksRenderer)
    end
end

function EMWorkflowFrame:onFrameOpen()
    EMWorkflowFrame:superClass().onFrameOpen(self)

    self:debugDumpElements()

    self:refreshData()

    self:setSoundSuppressed(true)
    FocusManager:setFocus(self.employeeList)
    self:setSoundSuppressed(false)
end

function EMWorkflowFrame:debugDumpElements()
    CustomUtils:info("=== [EMWorkflowFrame] DEBUG DUMP ===")

    local ids = {
        "mainBox", "employeeList", "fieldSelector", "vehicleSelector",
        "shiftStartSelector", "shiftEndSelector", "txtSkillsSummary",
        "availableTasksList", "queueList", "txtStatusMessage", "emptyText",
    }
    for _, id in ipairs(ids) do
        local el = self[id]
        if el ~= nil then
            local typeName = el.typeName or el.name or "?"
            local visible = "?"
            if el.getIsVisible then visible = tostring(el:getIsVisible()) end
            CustomUtils:info("  [OK] self.%-25s => type=%-20s visible=%s", id, typeName, visible)
        else
            CustomUtils:info("  [MISSING] self.%s => nil", id)
        end
    end

    CustomUtils:info("--- Child element tree ---")
    self:debugDumpTree(self, 0, 3)

    CustomUtils:info("=== END DEBUG DUMP ===")
end

function EMWorkflowFrame:debugDumpTree(element, depth, maxDepth)
    if depth > maxDepth then return end
    if element == nil then return end

    local indent = string.rep("  ", depth)
    local id = element.id or "(no id)"
    local profile = element.profile or "(no profile)"
    local typeName = element.typeName or "(unknown)"
    local visible = "?"
    if element.getIsVisible then visible = tostring(element:getIsVisible()) end

    CustomUtils:info("%s[%s] id=%s profile=%s visible=%s", indent, typeName, id, profile, visible)

    if element.elements then
        for _, child in ipairs(element.elements) do
            self:debugDumpTree(child, depth + 1, maxDepth)
        end
    end
end

function EMWorkflowFrame:onFrameClose()
    EMWorkflowFrame:superClass().onFrameClose(self)
    self.hiredEmployees = {}
    self.ownedFields    = {}
    self.ownedVehicles  = {}
end

function EMWorkflowFrame:refresh()
    -- Called by EMGui:onOpen() to pre-load data
end

function EMWorkflowFrame:getNumberOfSections()
    return 1
end

function EMWorkflowFrame:getNumberOfItemsInSection(list, section)
    return #self.hiredEmployees
end

function EMWorkflowFrame:getTitleForSectionHeader(list, section)
    return ""
end

function EMWorkflowFrame:populateCellForItemInSection(list, section, index, cell)
    local emp = self.hiredEmployees[index]
    if emp == nil then return end

    local titleEl    = cell:getAttribute("title")
    local subtitleEl = cell:getAttribute("subtitle")
    local iconEl     = cell:getAttribute("icon")

    if titleEl then
        titleEl:setText(string.format("%s (ID:%d)", emp.name, emp.id))
    end
    if subtitleEl then
        local skills = emp.skills or {}
        subtitleEl:setText(string.format("D:%d H:%d T:%d",
            skills.driving or 1, skills.harvesting or 1, skills.technical or 1))
    end
    if iconEl then
        iconEl:setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_character")
    end
end

function EMWorkflowFrame:onListSelectionChanged(list, section, index)
    local emp = self.hiredEmployees[index]
    if emp then
        self:loadEmployeeData(emp)
    end
    self:updateMenuButtons()
end

function EMWorkflowFrame:refreshData()
    if g_employeeManager == nil then
        self.hiredEmployees = {}
    else
        self.hiredEmployees = g_employeeManager:getHiredEmployees()
    end

    self.employeeList:reloadData()

    local hasEmployees = #self.hiredEmployees > 0
    if self.mainBox    then self.mainBox:setVisible(hasEmployees) end
    if self.emptyText  then self.emptyText:setVisible(not hasEmployees) end

    if not hasEmployees then
        self:updateMenuButtons()
        return
    end

    self.ownedFields  = self:buildOwnedFieldsList()
    self.ownedVehicles = self:buildOwnedVehiclesList()

    local fieldTexts = { g_i18n:getText("em_none") }
    for _, f in ipairs(self.ownedFields) do
        table.insert(fieldTexts, f.label)
    end
    if self.fieldSelector then
        self.fieldSelector:setTexts(fieldTexts)
    end

    local vehicleTexts = { g_i18n:getText("em_none") }
    for _, v in ipairs(self.ownedVehicles) do
        table.insert(vehicleTexts, v.label)
    end
    if self.vehicleSelector then
        self.vehicleSelector:setTexts(vehicleTexts)
    end

    -- Select first employee
    self.employeeList:setSelectedIndex(1, true, 0)
    self:loadEmployeeData(self.hiredEmployees[1])
    self:updateMenuButtons()
end

function EMWorkflowFrame:loadEmployeeData(employee)
    if not employee then return end

    local fieldState = 1
    if employee.targetFieldId then
        for i, f in ipairs(self.ownedFields) do
            if f.id == employee.targetFieldId then
                fieldState = i + 1
                break
            end
        end
    end
    if self.fieldSelector then
        self.fieldSelector:setState(fieldState, false)
    end

    local vehicleState = 1
    if employee.assignedVehicleId then
        for i, v in ipairs(self.ownedVehicles) do
            if v.id == employee.assignedVehicleId then
                vehicleState = i + 1
                break
            end
        end
    end
    if self.vehicleSelector then
        self.vehicleSelector:setState(vehicleState, false)
    end

    if self.shiftStartSelector then
        self.shiftStartSelector:setState((employee.shiftStart or 6) + 1, false)
    end
    if self.shiftEndSelector then
        self.shiftEndSelector:setState((employee.shiftEnd or 18) + 1, false)
    end

    if self.txtSkillsSummary then
        local skills = employee.skills or {}
        self.txtSkillsSummary:setText(string.format(
            "%s: %d/5  |  %s: %d/5  |  %s: %d/5",
            g_i18n:getText("em_skill_driving"),    skills.driving or 1,
            g_i18n:getText("em_skill_harvesting"), skills.harvesting or 1,
            g_i18n:getText("em_skill_technical"),  skills.technical or 1
        ))
    end

    self:refreshAvailableTasks(employee)
    self:refreshQueueList(employee)

    if self.txtStatusMessage then
        self.txtStatusMessage:setText("")
    end
end

function EMWorkflowFrame:refreshAvailableTasks(employee)
    local tasks = {}
    if JobManager and JobManager.WORK_TYPE_TO_CATEGORY then
        for taskName, _ in pairs(JobManager.WORK_TYPE_TO_CATEGORY) do
            if self:canEmployeeDoTask(employee, taskName) then
                table.insert(tasks, { label = taskName, value = taskName })
            end
        end
        table.sort(tasks, function(a, b) return a.label < b.label end)
    end
    self.availableTasksRenderer:setData(tasks)
    if self.availableTasksList then
        self.availableTasksList:reloadData()
    end
end

function EMWorkflowFrame:canEmployeeDoTask(employee, taskName)
    local req = EMWorkflowFrame.TASK_REQUIREMENTS[taskName]
    if not req then return true end
    local skills = employee.skills or {}
    local level = skills[req.skill] or 1
    return level >= req.level
end

function EMWorkflowFrame:refreshQueueList(employee)
    local queue = employee.taskQueue or {}
    local items = {}
    for i, taskName in ipairs(queue) do
        table.insert(items, { label = string.format("%d. %s", i, taskName), value = taskName })
    end
    self.queueTasksRenderer:setData(items)
    if self.queueList then
        self.queueList:reloadData()
    end
end

function EMWorkflowFrame:getSelectedEmployee()
    local idx = self.employeeList.selectedIndex
    if idx == nil or idx < 1 or idx > #self.hiredEmployees then return nil end
    return self.hiredEmployees[idx]
end

function EMWorkflowFrame:onFieldChanged()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    local state = self.fieldSelector:getState()
    if state == 1 then
        employee.targetFieldId = nil
    else
        local fieldEntry = self.ownedFields[state - 1]
        if fieldEntry then
            employee.targetFieldId = fieldEntry.id
        end
    end
end

function EMWorkflowFrame:onVehicleChanged()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    local state = self.vehicleSelector:getState()
    if state == 1 then
        employee:unassignVehicle()
    else
        local vehicleEntry = self.ownedVehicles[state - 1]
        if vehicleEntry then
            local vehicle = g_employeeManager:getVehicleById(vehicleEntry.id)
            if vehicle then
                employee:assignVehicle(vehicle)
            end
        end
    end
end

function EMWorkflowFrame:onShiftStartChanged()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    employee.shiftStart = self.shiftStartSelector:getState() - 1
end

function EMWorkflowFrame:onShiftEndChanged()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    employee.shiftEnd = self.shiftEndSelector:getState() - 1
end

function EMWorkflowFrame:onTaskAdd()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    if not self.availableTasksList then return end

    local idx = self.availableTasksList.selectedIndex
    local item = self.availableTasksRenderer.list[idx]
    if item then
        if not employee.taskQueue then employee.taskQueue = {} end
        table.insert(employee.taskQueue, item.value)
        self:refreshQueueList(employee)
    end
end

function EMWorkflowFrame:onTaskRemove()
    local employee = self:getSelectedEmployee()
    if not employee then return end
    if not self.queueList then return end

    local idx = self.queueList.selectedIndex
    if idx > 0 and employee.taskQueue and #employee.taskQueue >= idx then
        table.remove(employee.taskQueue, idx)
        self:refreshQueueList(employee)
    end
end

function EMWorkflowFrame:onTaskUp()
    local employee = self:getSelectedEmployee()
    if not employee or not employee.taskQueue then return end
    if not self.queueList then return end

    local idx = self.queueList.selectedIndex
    if idx > 1 then
        local tmp = employee.taskQueue[idx]
        employee.taskQueue[idx] = employee.taskQueue[idx - 1]
        employee.taskQueue[idx - 1] = tmp
        self:refreshQueueList(employee)
        self.queueList:setSelectedIndex(idx - 1)
    end
end

function EMWorkflowFrame:onTaskDown()
    local employee = self:getSelectedEmployee()
    if not employee or not employee.taskQueue then return end
    if not self.queueList then return end

    local idx = self.queueList.selectedIndex
    if idx < #employee.taskQueue then
        local tmp = employee.taskQueue[idx]
        employee.taskQueue[idx] = employee.taskQueue[idx + 1]
        employee.taskQueue[idx + 1] = tmp
        self:refreshQueueList(employee)
        self.queueList:setSelectedIndex(idx + 1)
    end
end

function EMWorkflowFrame:onSave()
    local employee = self:getSelectedEmployee()
    if not employee then return end

    if self.txtStatusMessage then
        self.txtStatusMessage:setText(string.format(g_i18n:getText("em_workflow_saved"), employee.name))
    end
    CustomUtils:info("[EMWorkflowFrame] Saved workflow for %s: %d tasks, field=%s, vehicle=%s, shift=%d-%d",
        employee.name, #(employee.taskQueue or {}),
        tostring(employee.targetFieldId), tostring(employee.assignedVehicleId),
        employee.shiftStart or 6, employee.shiftEnd or 18
    )
end

function EMWorkflowFrame:onSaveAndStart()
    local employee = self:getSelectedEmployee()
    if not employee then return end

    if not employee.targetFieldId then
        if self.txtStatusMessage then
            self.txtStatusMessage:setText(g_i18n:getText("em_error_no_field"))
        end
        return
    end
    if not employee.assignedVehicleId then
        if self.txtStatusMessage then
            self.txtStatusMessage:setText(g_i18n:getText("em_error_no_vehicle"))
        end
        return
    end
    local queue = employee.taskQueue or {}
    if #queue == 0 then
        if self.txtStatusMessage then
            self.txtStatusMessage:setText(g_i18n:getText("em_error_no_tasks"))
        end
        return
    end

    self:onSave()

    local firstTask = queue[1]
    employee.isAutonomous = true

    if g_employeeManager.jobManager:startFieldWork(employee, employee.targetFieldId, firstTask) then
        if self.txtStatusMessage then
            self.txtStatusMessage:setText(string.format(g_i18n:getText("em_workflow_started"),
                employee.name, employee.targetFieldId, firstTask))
        end
    else
        if self.txtStatusMessage then
            self.txtStatusMessage:setText(string.format(g_i18n:getText("em_workflow_start_failed"), employee.name))
        end
    end
end

function EMWorkflowFrame:buildOwnedFieldsList()
    local fields = {}
    if g_fieldManager and g_fieldManager.fields then
        local farmId = g_currentMission:getFarmId()
        for _, field in pairs(g_fieldManager.fields) do
            if field ~= nil and field.fieldId ~= nil then
                local farmland = field:getFarmland()
                if farmland and g_farmlandManager:getFarmlandOwner(farmland.id) == farmId then
                    local area = field.fieldArea or 0
                    table.insert(fields, {
                        id    = field.fieldId,
                        label = string.format("Field %d (%.1f ha)", field.fieldId, area),
                    })
                end
            end
        end
    end
    table.sort(fields, function(a, b) return a.id < b.id end)
    return fields
end

function EMWorkflowFrame:buildOwnedVehiclesList()
    local vehicles = {}
    if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
        local farmId = g_currentMission:getFarmId()
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle.ownerFarmId == farmId and vehicle.getIsDrivable and vehicle:getIsDrivable() then
                table.insert(vehicles, {
                    id    = vehicle.id,
                    label = vehicle:getName(),
                })
            end
        end
    end
    table.sort(vehicles, function(a, b) return a.label < b.label end)
    return vehicles
end

function EMWorkflowFrame:updateMenuButtons()
    local hasSelection = self:getSelectedEmployee() ~= nil

    self.menuButtonInfo = { self.backButtonInfo }
    if hasSelection then
        table.insert(self.menuButtonInfo, self.saveButtonInfo)
        table.insert(self.menuButtonInfo, self.saveStartButtonInfo)
    end

    self:setMenuButtonInfoDirty()
end

function EMWorkflowFrame:getMenuButtonInfo()
    return self.menuButtonInfo
end
