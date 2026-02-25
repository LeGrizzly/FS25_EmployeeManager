MenuEmployeeManager = {}

MenuEmployeeManager.CLASS_NAME = 'MenuEmployeeManager'
MenuEmployeeManager.MENU_PAGE_NAME = 'menuEmployeeManager'
MenuEmployeeManager.XML_FILENAME = g_modDirectory .. 'xml/gui/MenuEmployeeManager.xml'

MenuEmployeeManager.MENU_ICON_SLICE_ID = 'MenuEmployeeManager.menuIcon'

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

function MenuEmployeeManager.new()
    CustomUtils:debug("[MenuEmployeeManager] new()")
    local self = MenuEmployeeManager:superClass().new(nil, MenuEmployeeManager._mt)
    self.name      = "MenuEmployeeManager"
    self.className = "MenuEmployeeManager"

    self.menuButtonInfo = {}

    self.leftListRenderer       = EmployeeRenderer.new(self)

    self.currentMode     = MenuEmployeeManager.MODE.EMPLOYEES
    self.currentListType = MenuEmployeeManager.LIST_TYPE.NEW
    self.selectedFieldId = nil
    self.selectedCrop    = nil

    return self
end

function MenuEmployeeManager:onGuiSetupFinished()
    CustomUtils:debug("[MenuEmployeeManager] onGuiSetupFinished()")
    MenuEmployeeManager:superClass().onGuiSetupFinished(self)
end

function MenuEmployeeManager:initialize()
    CustomUtils:debug("[MenuEmployeeManager] initialize()")
    MenuEmployeeManager:superClass().initialize(self)

    self.leftListTable:setDataSource(self.leftListRenderer)
    self.leftListTable:setDelegate(self.leftListRenderer)

    self.leftListRenderer.indexChangedCallback = function(index)
        self:onLeftListSelectionChanged(index)
    end

    if self.workflowTable then
        self.workflowTable:setDataSource(self.workflowRenderer)
        self.workflowTable:setDelegate(self.workflowRenderer)
    end

    local switcherTexts = {}
    for _, textKey in ipairs(MenuEmployeeManager.LIST_STATE_TEXTS) do
        table.insert(switcherTexts, g_i18n:getText(textKey))
    end
    self.pageSwitcher:setTexts(switcherTexts)

    self.btnBack          = { inputAction = InputAction.MENU_BACK }
    self.btnHire          = { inputAction = InputAction.MENU_ACCEPT,  text = g_i18n:getText("em_btn_hire"),          callback = function() self:onHireEmployee() end }
    self.btnFire          = { inputAction = InputAction.MENU_EXTRA_2, text = g_i18n:getText("em_btn_fire"),          callback = function() self:onFireEmployee() end }
    self.btnStartWorkflow = { inputAction = InputAction.MENU_ACCEPT,  text = g_i18n:getText("em_btn_start_workflow"),callback = function() self:onStartWorkflow() end }
    self.btnOpenWorkflow  = { inputAction = InputAction.MENU_EXTRA_1, text = g_i18n:getText("em_btn_workflow_editor"), callback = function() self:onOpenWorkflowEditor() end }

    self.buttonSets = {
        [MenuEmployeeManager.LIST_TYPE.NEW]    = { self.btnBack, self.btnHire, self.btnOpenWorkflow },
        [MenuEmployeeManager.LIST_TYPE.ACTIVE] = { self.btnBack, self.btnOpenWorkflow },
        [MenuEmployeeManager.LIST_TYPE.OWNED]  = { self.btnBack, self.btnFire, self.btnOpenWorkflow },
        [MenuEmployeeManager.LIST_TYPE.FIELDS] = { self.btnBack, self.btnStartWorkflow, self.btnOpenWorkflow },
    }

    self.currentListType = self.pageSwitcher:getState() or MenuEmployeeManager.LIST_TYPE.NEW
    self:updateMenuButtons()
end

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

    local showWorkflow = (self.currentMode == MenuEmployeeManager.MODE.WORKFLOW)
    self.employeeInfoContainer:setVisible(false)
    self.workflowContainer:setVisible(false)
    self.noSelectedText:setVisible(true)

    local hasItem = self.leftListTable:getItemCount() > 0
    if hasItem then
        self.leftListTable:setSelectedIndex(1, true)
    end

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

function MenuEmployeeManager:displayEmployeeDetails(employee)
    self.employeeInfoContainer:setVisible(true)
    self.workflowContainer:setVisible(false)

    self.employeeName:setText(employee.name)
    self.employeeId:setText(string.format("ID: %d", employee.id))

    local statusKey = employee.isHired and "em_status_hired" or "em_status_available"
    self.employeeStatusValue:setText(g_i18n:getText(statusKey))

    if self.txtAssignedField then
        if employee.targetFieldId then
            self.txtAssignedField:setText(string.format("Field %d", employee.targetFieldId))
        else
            self.txtAssignedField:setText(g_i18n:getText("em_none"))
        end
    end

    self:displaySkills(employee)

    self:displayWorkStats(employee)

    if self.txtWorkflowSummary then
        local queue = employee.taskQueue or {}
        if #queue > 0 then
            local parts = {}
            for i, taskName in ipairs(queue) do
                table.insert(parts, string.format("%d. %s", i, taskName))
            end
            self.txtWorkflowSummary:setText(table.concat(parts, " > "))
        else
            self.txtWorkflowSummary:setText(g_i18n:getText("em_none"))
        end
    end

    local wage = employee.getDailyWage and employee:getDailyWage() or 0
    self.employeeWageValue:setText(g_i18n:formatMoney(wage, 0, true, false))
end

function MenuEmployeeManager:displaySkills(employee)
    local skills = employee.skills or { driving = 1, harvesting = 1, technical = 1 }
    local skillXP = employee.skillXP or { driving = 0, harvesting = 0, technical = 0 }

    local skillDefs = {
        { key = "driving",    starsId = "skillDrivingStars",    xpId = "skillDrivingXP" },
        { key = "harvesting", starsId = "skillHarvestingStars", xpId = "skillHarvestingXP" },
        { key = "technical",  starsId = "skillTechnicalStars",  xpId = "skillTechnicalXP" },
    }

    for _, def in ipairs(skillDefs) do
        local level = math.min(5, math.max(1, skills[def.key] or 1))
        local xp = skillXP[def.key] or 0
        local xpNeeded = level < 5 and (level * 100) or 0

        local stars = string.rep("*", level) .. string.rep("-", 5 - level)
        local starsText = string.format("[%s] %d/5", stars, level)

        local starsElement = self[def.starsId]
        if starsElement then
            starsElement:setText(starsText)
        end

        local xpElement = self[def.xpId]
        if xpElement then
            if level >= 5 then
                xpElement:setText("MAX")
            else
                xpElement:setText(string.format("XP: %d/%d", math.floor(xp), xpNeeded))
            end
        end
    end
end

function MenuEmployeeManager:displayWorkStats(employee)
    if self.statHoursWorked then
        local hours = employee.workTime or 0
        self.statHoursWorked:setText(string.format("%.1f h", hours))
    end

    if self.statCurrentJob then
        if employee.currentJob then
            local jobType = employee.currentJob.workType or employee.currentJob.type or "Unknown"
            local fieldId = employee.currentJob.fieldId
            if fieldId then
                self.statCurrentJob:setText(string.format("%s (Field %d)", jobType, fieldId))
            else
                self.statCurrentJob:setText(jobType)
            end
        else
            self.statCurrentJob:setText(g_i18n:getText("em_idle") or "Idle")
        end
    end
end

function MenuEmployeeManager:displayWorkflowDetails(fieldItem)
    self.employeeInfoContainer:setVisible(false)
    self.workflowContainer:setVisible(true)

    self.selectedFieldId = fieldItem.id

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

function MenuEmployeeManager:onOpenWorkflowEditor()
    if g_emGui ~= nil then
        g_gui:showGui("EMGui")
    elseif g_workflowEditor then
        g_workflowEditor:show()
    end
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

function MenuEmployeeManager:onMoneyChange()
    if g_localPlayer == nil or g_farmManager == nil then return end
    local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
    if farm == nil then return end

    local isNegative = farm.money <= -1
    local profileName = "fs25_shopMoney"
    
    if ShopMenu and ShopMenu.GUI_PROFILE then
        profileName = isNegative
            and ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE
            or  ShopMenu.GUI_PROFILE.SHOP_MONEY
    elseif isNegative then
        profileName = "fs25_shopMoneyNegative"
    end

    if self.currentBalanceText then
        self.currentBalanceText:applyProfile(profileName, nil, true)
        self.currentBalanceText:setText(g_i18n:formatMoney(farm.money, 0, true, false))
    end
end
