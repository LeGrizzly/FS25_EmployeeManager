--[[
    MenuEmployeeManager.lua
    PR Fix summary:
      • onGuiSetupFinished: bind leftListTable / pageSwitcher (new IDs from fixed XML)
      • onGuiSetupFinished: also bind workflowContainer, cropSelector, workflowTable,
        txtAssignedVehicle, txtAssignedField, availableTasksList, queueList, noSelectedText
      • onSwitchPage: was wired to onClick="onSwitchEmployeeDisplay" in old XML;
        now wired to onClick="onSwitchPage" — matches this file
      • updateContent: removed references to dead element IDs
      • onMoneyChange: guard against nil farm
      • displayEmployeeDetails: wire up task lists correctly
      • EmployeeRenderer cell attributes now match XML template names:
        "icon", "title", "subtitle"  (old XML used "employeeIcon"/"name"/"wage")
]]

MenuEmployeeManager = {}

MenuEmployeeManager.CLASS_NAME      = "MenuEmployeeManager"
MenuEmployeeManager.MENU_PAGE_NAME  = "menuEmployeeManager"
MenuEmployeeManager.XML_FILENAME    = g_modDirectory .. "xml/gui/MenuEmployeeManager.xml"

MenuEmployeeManager._mt = Class(MenuEmployeeManager, TabbedMenuFrameElement)

MenuEmployeeManager.MODE = {
    EMPLOYEES = 1,
    WORKFLOW  = 2,
}

MenuEmployeeManager.LIST_TYPE = {
    NEW    = 1,
    ACTIVE = 2,
    OWNED  = 3,
    FIELDS = 4,
}

MenuEmployeeManager.LIST_STATE_TEXTS = {
    "em_list_new",
    "em_list_active",
    "em_list_owned",
    "em_list_fields",
}

MenuEmployeeManager.HEADER_TITLE = "em_header_employees"

-- ─────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager.new()
    CustomUtils:debug("[MenuEmployeeManager] new()")
    local self = MenuEmployeeManager:superClass().new(nil, MenuEmployeeManager._mt)
    self.name      = "MenuEmployeeManager"
    self.className = "MenuEmployeeManager"

    self.menuButtonInfo = {}

    -- Renderers
    self.leftListRenderer       = EmployeeRenderer.new(self)
    self.workflowRenderer       = WorkflowStepRenderer.new(self)
    self.availableTasksRenderer = TaskListItemRenderer.new(self)
    self.queueTasksRenderer     = TaskListItemRenderer.new(self)

    self.currentMode     = MenuEmployeeManager.MODE.EMPLOYEES
    self.currentListType = MenuEmployeeManager.LIST_TYPE.NEW
    self.selectedFieldId = nil
    self.selectedCrop    = nil

    return self
end

-- ─────────────────────────────────────────────────────────
-- onGuiSetupFinished  (called once by g_gui after XML load)
-- Bind every element ID used in this file.
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:onGuiSetupFinished()
    CustomUtils:debug("[MenuEmployeeManager] onGuiSetupFinished()")
    MenuEmployeeManager:superClass().onGuiSetupFinished(self)

    -- Left panel
    self.leftListTable:setDataSource(self.leftListRenderer)
    self.leftListTable:setDelegate(self.leftListRenderer)

    self.leftListRenderer.indexChangedCallback = function(index)
        self:onLeftListSelectionChanged(index)
    end

    -- Workflow list
    if self.workflowTable then
        self.workflowTable:setDataSource(self.workflowRenderer)
        self.workflowTable:setDelegate(self.workflowRenderer)
    end

    -- Task lists inside employee detail panel
    if self.availableTasksList then
        self.availableTasksList:setDataSource(self.availableTasksRenderer)
        self.availableTasksList:setDelegate(self.availableTasksRenderer)
    end
    if self.queueList then
        self.queueList:setDataSource(self.queueTasksRenderer)
        self.queueList:setDelegate(self.queueTasksRenderer)
    end
end

-- ─────────────────────────────────────────────────────────
-- initialize  (called once by ModGui after addIngameMenuPage)
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:initialize()
    CustomUtils:debug("[MenuEmployeeManager] initialize()")
    MenuEmployeeManager:superClass().initialize(self)

    -- Populate tab switcher labels
    local switcherTexts = {}
    for _, textKey in ipairs(MenuEmployeeManager.LIST_STATE_TEXTS) do
        table.insert(switcherTexts, g_i18n:getText(textKey))
    end
    self.pageSwitcher:setTexts(switcherTexts)

    -- Define footer action buttons
    self.btnBack          = { inputAction = InputAction.MENU_BACK }
    self.btnHire          = { inputAction = InputAction.MENU_ACCEPT,  text = g_i18n:getText("em_btn_hire"),          callback = function() self:onHireEmployee() end }
    self.btnFire          = { inputAction = InputAction.MENU_EXTRA_2, text = g_i18n:getText("em_btn_fire"),          callback = function() self:onFireEmployee() end }
    self.btnAssign        = { inputAction = InputAction.MENU_EXTRA_1, text = g_i18n:getText("em_btn_assign"),        callback = function() self:onAssignVehicle() end }
    self.btnStartWorkflow = { inputAction = InputAction.MENU_ACCEPT,  text = g_i18n:getText("em_btn_start_workflow"),callback = function() self:onStartWorkflow() end }

    self.buttonSets = {
        [MenuEmployeeManager.LIST_TYPE.NEW]    = { self.btnBack, self.btnHire },
        [MenuEmployeeManager.LIST_TYPE.ACTIVE] = { self.btnBack, self.btnAssign },
        [MenuEmployeeManager.LIST_TYPE.OWNED]  = { self.btnBack, self.btnFire, self.btnAssign },
        [MenuEmployeeManager.LIST_TYPE.FIELDS] = { self.btnBack, self.btnStartWorkflow },
    }

    self.currentListType = self.pageSwitcher:getState() or MenuEmployeeManager.LIST_TYPE.NEW
    self:updateMenuButtons()
end

-- ─────────────────────────────────────────────────────────
-- Frame lifecycle
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:onFrameOpen()
    CustomUtils:debug("[MenuEmployeeManager] onFrameOpen()")
    MenuEmployeeManager:superClass().onFrameOpen(self)

    self:onMoneyChange()
    g_messageCenter:subscribe(MessageType.MONEY_CHANGED,    self.onMoneyChange,   self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_ADDED,   self.updateContent,   self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_REMOVED, self.updateContent,   self)

    self:updateContent()
end

function MenuEmployeeManager:onFrameClose()
    CustomUtils:debug("[MenuEmployeeManager] onFrameClose()")
    MenuEmployeeManager:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

-- ─────────────────────────────────────────────────────────
-- Tab switch  (onClick="onSwitchPage" in XML)
-- ─────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────
-- updateContent
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:updateContent()
    CustomUtils:debug("[MenuEmployeeManager] updateContent()")

    -- Header
    self.categoryHeaderText:setText(g_i18n:getText(MenuEmployeeManager.HEADER_TITLE))

    if g_employeeManager == nil then return end

    -- Build data per tab
    local available = g_employeeManager:getAvailableEmployees()
    local hired     = g_employeeManager:getHiredEmployees()

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
                        id   = field.fieldId,
                        name = string.format("Field %d", field.fieldId),
                        area = field.fieldArea or 0,
                    })
                end
            end
        end
    end
    table.sort(fields, function(a, b) return a.id < b.id end)

    local renderData = {
        [MenuEmployeeManager.LIST_TYPE.NEW]    = available,
        [MenuEmployeeManager.LIST_TYPE.ACTIVE] = active,
        [MenuEmployeeManager.LIST_TYPE.OWNED]  = hired,
        [MenuEmployeeManager.LIST_TYPE.FIELDS] = fields,
    }

    self.leftListRenderer:setData(renderData)
    self.leftListTable:reloadData()

    -- Show/hide panels
    local showWorkflow = (self.currentMode == MenuEmployeeManager.MODE.WORKFLOW)
    self.employeeInfoContainer:setVisible(false)
    self.workflowContainer:setVisible(false)
    self.noSelectedText:setVisible(true)

    -- Auto-select first item if list is non-empty
    local hasItem = self.leftListTable:getItemCount() > 0
    if hasItem then
        self.leftListTable:setSelectedIndex(1, true)
    end

    self:onLeftListSelectionChanged(self.leftListTable.selectedIndex)
    self:updateMenuButtons()
end

-- ─────────────────────────────────────────────────────────
-- List selection handler
-- ─────────────────────────────────────────────────────────
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
    else
        self:displayWorkflowDetails(item)
    end

    self:updateMenuButtons()
end

function MenuEmployeeManager:getSelectedItem()
    local index = self.leftListTable.selectedIndex
    if index == nil or index < 1 then return nil end
    local data = self.leftListRenderer.data
    if data == nil then return nil end
    local list = data[self.currentListType]
    if list == nil then return nil end
    return list[index]
end

-- ─────────────────────────────────────────────────────────
-- Employee detail panel
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:displayEmployeeDetails(employee)
    self.employeeInfoContainer:setVisible(true)
    self.workflowContainer:setVisible(false)

    self.employeeName:setText(employee.name)
    self.employeeId:setText(string.format("ID: %d", employee.id))

    local statusKey = employee.isHired and "em_status_hired" or "em_status_available"
    self.employeeStatusValue:setText(g_i18n:getText(statusKey))

    -- Assigned vehicle
    if employee.assignedVehicleId then
        local v = g_employeeManager:getVehicleById(employee.assignedVehicleId)
        self.txtAssignedVehicle:setText(v and v:getName() or g_i18n:getText("em_unknown"))
    else
        self.txtAssignedVehicle:setText(g_i18n:getText("em_none"))
    end

    -- Assigned field
    if employee.targetFieldId then
        self.txtAssignedField:setText(string.format("Field %d", employee.targetFieldId))
    else
        self.txtAssignedField:setText(g_i18n:getText("em_none"))
    end

    -- Daily wage
    local wage = employee.getDailyWage and employee:getDailyWage() or 0
    self.employeeWageValue:setText(g_i18n:formatMoney(wage, 0, true, false))

    -- Available tasks
    local allTasks = {}
    if JobManager and JobManager.WORK_TYPE_TO_CATEGORY then
        for taskName, _ in pairs(JobManager.WORK_TYPE_TO_CATEGORY) do
            table.insert(allTasks, { label = taskName, value = taskName })
        end
        table.sort(allTasks, function(a, b) return a.label < b.label end)
    end
    self.availableTasksRenderer:setData(allTasks)
    self.availableTasksList:reloadData()

    -- Task queue
    local queue = employee.taskQueue or {}
    local queueItems = {}
    for _, taskName in ipairs(queue) do
        table.insert(queueItems, { label = taskName, value = taskName })
    end
    self.queueTasksRenderer:setData(queueItems)
    self.queueList:reloadData()
end

-- ─────────────────────────────────────────────────────────
-- Workflow panel
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:displayWorkflowDetails(fieldItem)
    self.employeeInfoContainer:setVisible(false)
    self.workflowContainer:setVisible(true)

    self.selectedFieldId = fieldItem.id

    -- Populate crop selector once
    if self.cropSelector and #self.cropSelector.texts == 0 and g_employeeManager.cropManager then
        local cropNames = {}
        for name, _ in pairs(g_employeeManager.cropManager.crops) do
            table.insert(cropNames, name)
        end
        table.sort(cropNames)
        self.cropSelector:setTexts(cropNames)
    end

    self:updateWorkflowSteps()
end

function MenuEmployeeManager:onCropChanged()
    if self.cropSelector then
        local state    = self.cropSelector:getState()
        local cropName = self.cropSelector.texts[state]
        self.selectedCrop = cropName
        self:updateWorkflowSteps()
    end
end

function MenuEmployeeManager:updateWorkflowSteps()
    if not self.cropSelector then return end
    local state    = self.cropSelector:getState()
    local cropName = self.cropSelector.texts and self.cropSelector.texts[state]
    self.selectedCrop = cropName
    if not cropName then return end

    local cropData = g_employeeManager.cropManager.crops[cropName]
    if cropData then
        self.workflowRenderer:setSteps(cropData.steps, {})
        self.workflowTable:reloadData()
    end
end

function MenuEmployeeManager:onStartWorkflow()
    if not self.selectedFieldId or not self.selectedCrop then return end

    local fieldId    = self.selectedFieldId
    local cropName   = self.selectedCrop
    local assignments = self.workflowRenderer.assignments

    g_employeeManager:setFieldConfig(fieldId, cropName, assignments)

    local field = g_fieldManager:getFieldById(fieldId)
    if not field then return end

    local nextStep, reason = g_employeeManager.cropManager:getNextStep(field, cropName)

    if nextStep == nil or nextStep == "WAIT" then
        InfoDialog.show(string.format("Workflow configured for Field %d.\nStatus: %s",
            fieldId, reason or "Waiting"))
        return
    end

    -- Find an idle employee
    local assignedEmployee = g_employeeManager:getAssignedEmployeeForStep(fieldId, nextStep)
    if not assignedEmployee then
        for _, emp in ipairs(g_employeeManager:getHiredEmployees()) do
            if emp.currentJob == nil then
                assignedEmployee = emp
                break
            end
        end
    end

    if assignedEmployee then
        g_employeeManager:consoleSetTargetCrop(assignedEmployee.id, fieldId, cropName)
        if g_employeeManager.jobManager:startFieldWork(assignedEmployee, fieldId, nextStep) then
            InfoDialog.show(string.format("Workflow STARTED!\nField: %d (%s)\nTask: %s\nEmployee: %s",
                fieldId, cropName, nextStep, assignedEmployee.name))
        else
            InfoDialog.show(string.format("Failed to start workflow for %s (check vehicle/equipment)",
                assignedEmployee.name))
        end
    else
        InfoDialog.show("Workflow configured, but no employee available for task: " .. nextStep)
    end
end

-- ─────────────────────────────────────────────────────────
-- Task queue buttons
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:onTaskAdd()
    local employee = self:getSelectedItem()
    if not employee then return end
    local idx  = self.availableTasksList.selectedIndex
    local item = self.availableTasksRenderer.list[idx]
    if item then
        if not employee.taskQueue then employee.taskQueue = {} end
        table.insert(employee.taskQueue, item.value)
        self:displayEmployeeDetails(employee)
    end
end

function MenuEmployeeManager:onTaskRemove()
    local employee = self:getSelectedItem()
    if not employee then return end
    local idx = self.queueList.selectedIndex
    if idx > 0 and employee.taskQueue then
        table.remove(employee.taskQueue, idx)
        self:displayEmployeeDetails(employee)
    end
end

function MenuEmployeeManager:onTaskUp()
    local employee = self:getSelectedItem()
    if not employee then return end
    local idx = self.queueList.selectedIndex
    if idx > 1 and employee.taskQueue then
        local t = employee.taskQueue[idx]
        employee.taskQueue[idx]     = employee.taskQueue[idx - 1]
        employee.taskQueue[idx - 1] = t
        self:displayEmployeeDetails(employee)
        self.queueList:setSelectedIndex(idx - 1)
    end
end

function MenuEmployeeManager:onTaskDown()
    local employee = self:getSelectedItem()
    if not employee then return end
    local idx = self.queueList.selectedIndex
    if employee.taskQueue and idx < #employee.taskQueue then
        local t = employee.taskQueue[idx]
        employee.taskQueue[idx]     = employee.taskQueue[idx + 1]
        employee.taskQueue[idx + 1] = t
        self:displayEmployeeDetails(employee)
        self.queueList:setSelectedIndex(idx + 1)
    end
end

-- ─────────────────────────────────────────────────────────
-- Global action buttons
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:onHireEmployee()
    local employee = self:getSelectedItem()
    if employee == nil then return end
    YesNoDialog.show(
        function(_, yes)
            if yes then
                g_employeeManager:hireEmployee(employee.id)
                self:updateContent()
            end
        end,
        self,
        string.format(g_i18n:getText("em_dialog_hire_yes_no"), employee.name),
        g_i18n:getText("em_dialog_hire_yes_no_btn")
    )
end

function MenuEmployeeManager:onFireEmployee()
    local employee = self:getSelectedItem()
    if employee == nil then return end
    YesNoDialog.show(
        function(_, yes)
            if yes then
                g_employeeManager:fireEmployee(employee.id)
                self:updateContent()
            end
        end,
        self,
        string.format(g_i18n:getText("em_dialog_fire_yes_no"), employee.name),
        g_i18n:getText("em_dialog_fire_yes_no_btn")
    )
end

function MenuEmployeeManager:onAssignVehicle()
    local employee = self:getSelectedItem()
    if employee == nil then return end

    local farmId = g_currentMission:getFarmId()
    local assigned = {}
    for _, emp in ipairs(g_employeeManager.employees) do
        if emp.assignedVehicleId then assigned[emp.assignedVehicleId] = true end
    end

    local foundVehicle = nil
    if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle.ownerFarmId == farmId
            and vehicle.getIsMotorStarted ~= nil
            and not assigned[vehicle.id] then
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

-- ─────────────────────────────────────────────────────────
-- Footer button management
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:updateMenuButtons()
    if self.buttonSets == nil or self.menuButtonInfo == nil then return end

    local listType   = self.currentListType or MenuEmployeeManager.LIST_TYPE.NEW
    local baseButtons = self.buttonSets[listType] or { self.btnBack }
    local item        = self:getSelectedItem()

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

-- ─────────────────────────────────────────────────────────
-- Money display
-- ─────────────────────────────────────────────────────────
function MenuEmployeeManager:onMoneyChange()
    if g_localPlayer == nil then return end
    local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
    if farm == nil then return end

    local isNegative = farm.money <= -1
    local profileName = isNegative
        and ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE
        or  ShopMenu.GUI_PROFILE.SHOP_MONEY
    self.currentBalanceText:applyProfile(profileName, nil, true)
    self.currentBalanceText:setText(g_i18n:formatMoney(farm.money, 0, true, false))
end
