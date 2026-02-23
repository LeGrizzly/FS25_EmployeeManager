MenuEmployeeManager = {}

MenuEmployeeManager.CLASS_NAME = 'MenuEmployeeManager'
MenuEmployeeManager.MENU_PAGE_NAME = 'menuEmployeeManager'
MenuEmployeeManager.XML_FILENAME = g_modDirectory .. 'xml/gui/MenuEmployeeManager.xml'
MenuEmployeeManager.MENU_ICON_SLICE_ID = 'employeeManager.menuIcon'
MenuEmployeeManager._mt = Class(MenuEmployeeManager, TabbedMenuFrameElement)

MenuEmployeeManager.MODE = {
    EMPLOYEES = 1,
    WORKFLOW = 2
}

MenuEmployeeManager.LIST_TYPE = {
    NEW = 1,
    ACTIVE = 2,
    OWNED = 3,
    FIELDS = 4 -- New list type for Workflow mode
}

MenuEmployeeManager.LIST_STATE_TEXTS = { "em_list_new", "em_list_active", "em_list_owned", "em_list_fields" }
MenuEmployeeManager.HEADER_TITLE = "em_header_employees"

function MenuEmployeeManager.new(i18n, messageCenter)
    CustomUtils:debug("[MenuEmployeeManager] new()")
    local self = MenuEmployeeManager:superClass().new(nil, MenuEmployeeManager._mt)
    self.name = "MenuEmployeeManager"
    self.className = "MenuEmployeeManager"
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.menuButtonInfo = {}
    
    -- Renderers
    self.leftListRenderer = EmployeeRenderer.new(self) 
    self.workflowRenderer = WorkflowStepRenderer.new(self)
    self.availableTasksRenderer = TaskListItemRenderer.new(self)
    self.queueTasksRenderer = TaskListItemRenderer.new(self)
    
    self.currentMode = MenuEmployeeManager.MODE.EMPLOYEES
    self.selectedFieldId = nil
    self.selectedCrop = nil
    
    return self
end

function MenuEmployeeManager:onGuiSetupFinished()
    CustomUtils:debug("[MenuEmployeeManager] onGuiSetupFinished()")
    MenuEmployeeManager:superClass().onGuiSetupFinished(self)
    
    -- Setup Left List
    self.leftListTable:setDataSource(self.leftListRenderer)
    self.leftListTable:setDelegate(self.leftListRenderer)
    
    -- Setup Workflow List (Auto)
    if self.workflowTable then
        self.workflowTable:setDataSource(self.workflowRenderer)
        self.workflowTable:setDelegate(self.workflowRenderer)
    end
    
    -- Setup Custom Workflow Lists
    if self.availableTasksList then
        self.availableTasksList:setDataSource(self.availableTasksRenderer)
        self.availableTasksList:setDelegate(self.availableTasksRenderer)
    end
    if self.queueList then
        self.queueList:setDataSource(self.queueTasksRenderer)
        self.queueList:setDelegate(self.queueTasksRenderer)
    end
    
    self.leftListRenderer.indexChangedCallback = function(index)
        self:onLeftListSelectionChanged(index)
    end
end

function MenuEmployeeManager:initialize()
    CustomUtils:debug("[MenuEmployeeManager] initialize()")
    MenuEmployeeManager:superClass().initialize(self)
    
    local switcherTexts = {}
    for _, textKey in ipairs(MenuEmployeeManager.LIST_STATE_TEXTS) do
        table.insert(switcherTexts, g_i18n:getText(textKey))
    end
    self.pageSwitcher:setTexts(switcherTexts)

    -- Define Buttons
    self.btnBack = { inputAction = InputAction.MENU_BACK }
    self.btnHire = { inputAction = InputAction.MENU_ACCEPT, text = g_i18n:getText("em_btn_hire"), callback = function() self:onHireEmployee() end }
    self.btnFire = { inputAction = InputAction.MENU_EXTRA_2, text = g_i18n:getText("em_btn_fire"), callback = function() self:onFireEmployee() end }
    self.btnAssign = { inputAction = InputAction.MENU_EXTRA_1, text = g_i18n:getText("em_btn_assign"), callback = function() self:onAssignVehicle() end }
    self.btnStartWorkflow = { inputAction = InputAction.MENU_ACCEPT, text = g_i18n:getText("em_btn_start_workflow"), callback = function() self:onStartWorkflow() end }
    
    -- Button Sets
    self.buttonSets = {}
    self.buttonSets[MenuEmployeeManager.LIST_TYPE.NEW] = { self.btnBack, self.btnHire }
    self.buttonSets[MenuEmployeeManager.LIST_TYPE.ACTIVE] = { self.btnBack, self.btnAssign }
    self.buttonSets[MenuEmployeeManager.LIST_TYPE.OWNED] = { self.btnBack, self.btnFire, self.btnAssign }
    self.buttonSets[MenuEmployeeManager.LIST_TYPE.FIELDS] = { self.btnBack, self.btnStartWorkflow }

    self.currentListType = self.pageSwitcher:getState() or MenuEmployeeManager.LIST_TYPE.NEW
    self:updateMenuButtons()
end

function MenuEmployeeManager:onFrameOpen()
    CustomUtils:debug("[MenuEmployeeManager] onFrameOpen()")
    MenuEmployeeManager:superClass().onFrameOpen(self)
    self:onMoneyChange()
    g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_ADDED, self.updateContent, self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_REMOVED, self.updateContent, self)
    self:updateContent()
end

function MenuEmployeeManager:onFrameClose()
    CustomUtils:debug("[MenuEmployeeManager] onFrameClose()")
    MenuEmployeeManager:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuEmployeeManager:onSwitchPage()
    CustomUtils:debug("[MenuEmployeeManager] onSwitchPage()")
    self.currentListType = self.pageSwitcher:getState()
    
    if self.currentListType == MenuEmployeeManager.LIST_TYPE.FIELDS then
        self.currentMode = MenuEmployeeManager.MODE.WORKFLOW
    else
        self.currentMode = MenuEmployeeManager.MODE.EMPLOYEES
    end
    
    self:updateContent()
end

function MenuEmployeeManager:updateContent()
    CustomUtils:debug("[MenuEmployeeManager] updateContent()")
    self.categoryHeaderText:setText(g_i18n:getText(MenuEmployeeManager.HEADER_TITLE))

    if g_employeeManager == nil then return end

    -- Refresh Data Sources
    local available = g_employeeManager:getAvailableEmployees()
    local hired = g_employeeManager:getHiredEmployees()
    local active = {}
    for _, e in ipairs(hired) do
        if e.currentJob ~= nil then table.insert(active, e) end
    end
    
    local fields = {}
    if g_fieldManager and g_fieldManager.fields then
        local farmId = g_currentMission:getFarmId()
        for _, field in pairs(g_fieldManager.fields) do
             if field ~= nil and field.fieldId ~= nil then
                 local farmland = field:getFarmland()
                 if farmland and g_farmlandManager:getFarmlandOwner(farmland.id) == farmId then
                     table.insert(fields, { 
                        id = field.fieldId, 
                        name = string.format("Field %d", field.fieldId), 
                        area = field.fieldArea or 0
                     })
                 end
             end
        end
    end
    table.sort(fields, function(a,b) return a.id < b.id end)

    local renderData = {
        [MenuEmployeeManager.LIST_TYPE.NEW] = available,
        [MenuEmployeeManager.LIST_TYPE.ACTIVE] = active,
        [MenuEmployeeManager.LIST_TYPE.OWNED] = hired,
        [MenuEmployeeManager.LIST_TYPE.FIELDS] = fields
    }

    self.leftListRenderer:setData(renderData)
    self.leftListTable:reloadData()

    local showWorkflow = (self.currentMode == MenuEmployeeManager.MODE.WORKFLOW)
    self.employeeInfoContainer:setVisible(not showWorkflow)
    self.workflowContainer:setVisible(showWorkflow)
    self.noSelectedText:setVisible(true)

    local hasItem = self.leftListTable:getItemCount() > 0
    self.leftListTable:setSelectedIndex(hasItem and 1 or 0)
    
    self:onLeftListSelectionChanged(self.leftListTable.selectedIndex)
    self:updateMenuButtons()
end

function MenuEmployeeManager:onLeftListSelectionChanged(index)
    if index == nil or index < 1 then
        self.noSelectedText:setVisible(true)
        self.employeeInfoContainer:setVisible(false)
        self.workflowContainer:setVisible(false)
        return
    end

    local item = self:getSelectedItem()
    if item == nil then return end

    self.noSelectedText:setVisible(false)

    if self.currentMode == MenuEmployeeManager.MODE.EMPLOYEES then
        self:displayEmployeeDetails(item)
    elseif self.currentMode == MenuEmployeeManager.MODE.WORKFLOW then
        self:displayWorkflowDetails(item)
    end
    
    self:updateMenuButtons()
end

function MenuEmployeeManager:getSelectedItem()
    local index = self.leftListTable.selectedIndex
    if index == nil or index < 1 then return nil end
    local listType = self.currentListType
    local list = self.leftListRenderer.data and self.leftListRenderer.data[listType]
    if list == nil then return nil end
    return list[index]
end

-- VIEW: EMPLOYEE DETAILS
function MenuEmployeeManager:displayEmployeeDetails(employee)
    self.employeeInfoContainer:setVisible(true)
    self.workflowContainer:setVisible(false)
    
    -- Header Info
    self.employeeName:setText(employee.name)
    local statusText = employee.isHired and g_i18n:getText("em_status_hired") or g_i18n:getText("em_status_available")
    self.employeeStatusValue:setText(statusText)
    
    -- Assignments Display
    if employee.assignedVehicleId then
        local v = g_employeeManager:getVehicleById(employee.assignedVehicleId)
        self.txtAssignedVehicle:setText(v and v:getName() or "Unknown")
    else
        self.txtAssignedVehicle:setText("None")
    end
    
    if employee.targetFieldId then
        self.txtAssignedField:setText(string.format("Field %d", employee.targetFieldId))
    else
        self.txtAssignedField:setText("None")
    end

    -- Populate Available Tasks
    local allTasks = {}
    for taskName, _ in pairs(JobManager.WORK_TYPE_TO_CATEGORY) do
        table.insert(allTasks, { label = taskName, value = taskName })
    end
    table.sort(allTasks, function(a,b) return a.label < b.label end)
    self.availableTasksRenderer:setData(allTasks)
    self.availableTasksList:reloadData()
    
    -- Populate Queue
    local queue = employee.taskQueue or {}
    local queueItems = {}
    for _, taskName in ipairs(queue) do
        table.insert(queueItems, { label = taskName, value = taskName })
    end
    self.queueTasksRenderer:setData(queueItems)
    self.queueList:reloadData()
end

-- VIEW: WORKFLOW EDITOR (Global)
function MenuEmployeeManager:displayWorkflowDetails(fieldItem)
    self.employeeInfoContainer:setVisible(false)
    self.workflowContainer:setVisible(true)
    
    self.selectedFieldId = fieldItem.id
    
    if #self.cropSelector.texts == 0 and g_employeeManager.cropManager then
        local cropNames = {}
        for name, _ in pairs(g_employeeManager.cropManager.crops) do
            table.insert(cropNames, name)
        end
        table.sort(cropNames)
        self.cropSelector:setTexts(cropNames)
    end
    
    self:updateWorkflowSteps()
end

function MenuEmployeeManager:onCropChanged(state)
    if self.cropSelector then
        local state = self.cropSelector:getState()
        local cropName = self.cropSelector.texts[state]
        self.selectedCrop = cropName
        self:updateWorkflowSteps()
    end
end

function MenuEmployeeManager:onFieldChanged(element)
end

function MenuEmployeeManager:updateWorkflowSteps()
    local cropState = self.cropSelector:getState()
    local cropName = self.cropSelector.texts[cropState]
    self.selectedCrop = cropName

    if not self.selectedCrop then return end
    
    local cropData = g_employeeManager.cropManager.crops[self.selectedCrop]
    if cropData then
        self.workflowRenderer:setSteps(cropData.steps, {}) 
        self.workflowTable:reloadData()
    end
end

function MenuEmployeeManager:onStartWorkflow()
    if self.selectedFieldId and self.selectedCrop then
        local fieldId = self.selectedFieldId
        local cropName = self.selectedCrop
        local assignments = self.workflowRenderer.assignments
        
        g_employeeManager:setFieldConfig(fieldId, cropName, assignments)
        
        local field = g_fieldManager:getFieldById(fieldId)
        if not field then return end
        
        local nextStep, reason = g_employeeManager.cropManager:getNextStep(field, cropName)
        
        if nextStep == nil or nextStep == "WAIT" then
            InfoDialog.show(string.format("Workflow Configured for Field %d.\nStatus: %s", fieldId, reason or "Waiting"))
            return
        end
        
        local assignedEmployee = g_employeeManager:getAssignedEmployeeForStep(fieldId, nextStep)
        
        if not assignedEmployee then
            local hired = g_employeeManager:getHiredEmployees()
            for _, emp in ipairs(hired) do
                if emp.currentJob == nil then
                    assignedEmployee = emp
                    break
                end
            end
        end
        
        if assignedEmployee then
            g_employeeManager:consoleSetTargetCrop(assignedEmployee.id, fieldId, cropName)
            if g_employeeManager.jobManager:startFieldWork(assignedEmployee, fieldId, nextStep) then
                 InfoDialog.show(string.format("Workflow STARTED!\nField: %d (%s)\nTask: %s\nEmployee: %s", fieldId, cropName, nextStep, assignedEmployee.name))
            else
                 InfoDialog.show(string.format("Failed to start workflow for %s (Check vehicle/equipment)", assignedEmployee.name))
            end
        else
            InfoDialog.show("Workflow Configured, but no employee available for task: " .. nextStep)
        end
    end
end

-- --- EMPLOYEE DETAILS BUTTONS ---

function MenuEmployeeManager:onAssignVehicleClick()
    self:onAssignVehicle()
end

function MenuEmployeeManager:onAssignFieldClick()
    local employee = self:getSelectedItem()
    if not employee then return end
    
    local fields = g_fieldManager.fields
    local ownedFields = {}
    local farmId = g_currentMission:getFarmId()
    
    for _, f in pairs(fields) do
        if f.fieldId then
             local fl = f:getFarmland()
             if fl and g_farmlandManager:getFarmlandOwner(fl.id) == farmId then
                 table.insert(ownedFields, f.fieldId)
             end
        end
    end
    table.sort(ownedFields)
    
    if #ownedFields == 0 then
        InfoDialog.show("You don't own any fields!")
        return
    end
    
    local currentIndex = 0
    for i, fid in ipairs(ownedFields) do
        if fid == employee.targetFieldId then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = currentIndex + 1
    if nextIndex > #ownedFields then nextIndex = 1 end
    
    local newFieldId = ownedFields[nextIndex]
    employee.targetFieldId = newFieldId
    g_employeeManager:setFieldConfig(newFieldId, "CUSTOM", {})
    
    self.txtAssignedField:setText(string.format("Field %d", newFieldId))
end

function MenuEmployeeManager:onTaskAdd()
    local employee = self:getSelectedItem()
    if not employee then return end
    
    local selectedIndex = self.availableTasksList.selectedIndex
    local item = self.availableTasksRenderer.list[selectedIndex]
    
    if item then
        if not employee.taskQueue then employee.taskQueue = {} end
        table.insert(employee.taskQueue, item.value)
        self:displayEmployeeDetails(employee)
    end
end

function MenuEmployeeManager:onTaskRemove()
    local employee = self:getSelectedItem()
    if not employee then return end
    
    local selectedIndex = self.queueList.selectedIndex
    if selectedIndex > 0 and employee.taskQueue then
        table.remove(employee.taskQueue, selectedIndex)
        self:displayEmployeeDetails(employee)
    end
end

function MenuEmployeeManager:onTaskUp()
    local employee = self:getSelectedItem()
    if not employee then return end
    
    local idx = self.queueList.selectedIndex
    if idx > 1 and employee.taskQueue then
        local temp = employee.taskQueue[idx]
        employee.taskQueue[idx] = employee.taskQueue[idx-1]
        employee.taskQueue[idx-1] = temp
        self:displayEmployeeDetails(employee)
        self.queueList:setSelectedIndex(idx - 1)
    end
end

function MenuEmployeeManager:onTaskDown()
    local employee = self:getSelectedItem()
    if not employee then return end
    
    local idx = self.queueList.selectedIndex
    if employee.taskQueue and idx < #employee.taskQueue then
        local temp = employee.taskQueue[idx]
        employee.taskQueue[idx] = employee.taskQueue[idx+1]
        employee.taskQueue[idx+1] = temp
        self:displayEmployeeDetails(employee)
        self.queueList:setSelectedIndex(idx + 1)
    end
end

-- --- GLOBAL BUTTONS ---

function MenuEmployeeManager:onAssignVehicle()
    local employee = self:getSelectedItem()
    if employee == nil then return end
    
    local farmId = g_currentMission:getFarmId()
    local assignedVehicleIds = {}
    for _, emp in ipairs(g_employeeManager.employees) do
        if emp.assignedVehicleId then
            assignedVehicleIds[emp.assignedVehicleId] = true
        end
    end
    
    local foundVehicle = nil
    if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle.ownerFarmId == farmId and vehicle.getIsMotorStarted ~= nil and not assignedVehicleIds[vehicle.id] then
                foundVehicle = vehicle
                break
            end
        end
    end
    
    if foundVehicle then
        g_employeeManager:assignVehicleToEmployee(employee.id, foundVehicle.id)
        self:updateContent()
        InfoDialog.show(string.format("Assigned %s to %s", foundVehicle:getName(), employee.name))
    else
        InfoDialog.show("No free drivable vehicles found.")
    end
end

function MenuEmployeeManager:onHireEmployee()
    local employee = self:getSelectedItem()
    if employee == nil then return end
    YesNoDialog.show(function(_, yes) if yes then g_employeeManager:hireEmployee(employee.id) self:updateContent() end end, self, string.format(g_i18n:getText("em_dialog_hire_yes_no"), employee.name), g_i18n:getText("em_dialog_hire_yes_no_btn"))
end

function MenuEmployeeManager:onFireEmployee()
    local employee = self:getSelectedItem()
    if employee == nil then return end
    YesNoDialog.show(function(_, yes) if yes then g_employeeManager:fireEmployee(employee.id) self:updateContent() end end, self, string.format(g_i18n:getText("em_dialog_fire_yes_no"), employee.name), g_i18n:getText("em_dialog_fire_yes_no_btn"))
end

function MenuEmployeeManager:updateMenuButtons()
    if self.buttonSets == nil or self.menuButtonInfo == nil then return end

    local listType = self.currentListType or MenuEmployeeManager.LIST_TYPE.NEW
    local baseButtons = self.buttonSets[listType] or { self.btnBack }
    local item = self:getSelectedItem()
    
    local filtered = {}
    for _, btn in ipairs(baseButtons) do
        if self:shouldShowButton(btn, listType, item) then
            table.insert(filtered, btn)
        end
    end
    self.menuButtonInfo.employees = filtered
    self:setMenuButtonInfoDirty()
end

function MenuEmployeeManager:shouldShowButton(button, listType, item)
    if button == self.btnBack then return true end
    return item ~= nil
end

function MenuEmployeeManager:getMenuButtonInfo()
    return self.menuButtonInfo.employees or { self.btnBack }
end

function MenuEmployeeManager:onMoneyChange()
    if g_localPlayer ~= nil then
        local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
        self.currentBalanceText:applyProfile(farm.money <= -1 and ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE or ShopMenu.GUI_PROFILE.SHOP_MONEY, nil, true)
        self.currentBalanceText:setText(g_i18n:formatMoney(farm.money, 0, true, false))
    end
end
