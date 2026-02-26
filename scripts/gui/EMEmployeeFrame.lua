EMEmployeeFrame = {}

local EMEmployeeFrame_mt = Class(EMEmployeeFrame, TabbedMenuFrameElement)

EMEmployeeFrame.LIST_TYPE = {
    AVAILABLE = 1,
    HIRED     = 2,
}

function EMEmployeeFrame:new()
    local self = TabbedMenuFrameElement.new(nil, EMEmployeeFrame_mt)
    self.employees       = {}
    self.currentListType = EMEmployeeFrame.LIST_TYPE.AVAILABLE
    self.menuButtonInfo  = {}
    return self
end

function EMEmployeeFrame:copyAttributes(src)
    EMEmployeeFrame:superClass().copyAttributes(self, src)
end

function EMEmployeeFrame:initialize()
    self.backButtonInfo = { inputAction = InputAction.MENU_BACK }
    self.hireButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_ACTIVATE,
        text        = g_i18n:getText("em_btn_hire"),
        callback    = function() self:onHireEmployee() end,
    }
    self.fireButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_EXTRA_2,
        text        = g_i18n:getText("em_btn_fire"),
        callback    = function() self:onFireEmployee() end,
    }
    self.editWorkflowButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_EXTRA_1,
        text        = g_i18n:getText("em_btn_workflow_editor"),
        callback    = function() self:onEditWorkflow() end,
    }
    self.trainButtonInfo = {
        profile     = "buttonActivate",
        inputAction = InputAction.MENU_EXTRA_3,
        text        = g_i18n:getText("em_btn_train"),
        callback    = function() self:onTrainEmployee() end,
    }

    local switcherTexts = {
        g_i18n:getText("em_list_new"),
        g_i18n:getText("em_list_owned"),
    }
    self.listSwitcher:setTexts(switcherTexts)
end

function EMEmployeeFrame:onGuiSetupFinished()
    EMEmployeeFrame:superClass().onGuiSetupFinished(self)
    self.employeeList:setDataSource(self)
    self.employeeList:setDelegate(self)
end

function EMEmployeeFrame:onFrameOpen()
    EMEmployeeFrame:superClass().onFrameOpen(self)
    self:rebuildTable()

    self:setSoundSuppressed(true)
    FocusManager:setFocus(self.employeeList)
    self:setSoundSuppressed(false)
end

function EMEmployeeFrame:onFrameClose()
    EMEmployeeFrame:superClass().onFrameClose(self)
    self.employees = {}
end

function EMEmployeeFrame:refresh()
    -- Called by EMGui:onOpen() to pre-load data
end

function EMEmployeeFrame:getNumberOfSections()
    return 1
end

function EMEmployeeFrame:getNumberOfItemsInSection(list, section)
    return #self.employees
end

function EMEmployeeFrame:getTitleForSectionHeader(list, section)
    return ""
end

function EMEmployeeFrame:populateCellForItemInSection(list, section, index, cell)
    local emp = self.employees[index]
    if emp == nil then return end

    local titleEl    = cell:getAttribute("title")
    local subtitleEl = cell:getAttribute("subtitle")
    local iconEl     = cell:getAttribute("icon")

    if titleEl then
        titleEl:setText(emp.name or "???")
    end

    if subtitleEl then
        local hourly = emp.getHourlyWage and emp:getHourlyWage() or 0
        local traitName = emp.getTraitName and emp:getTraitName() or ""
        if emp.isHired then
            local statusText = emp.currentJob and (emp.currentJob.workType or "Working") or "Idle"
            subtitleEl:setText(string.format("%s | %s | %s/h", statusText, traitName, g_i18n:formatMoney(hourly, 0, true, false)))
        else
            subtitleEl:setText(string.format("%s | %s/h", traitName, g_i18n:formatMoney(hourly, 0, true, false)))
        end
    end

    if iconEl then
        iconEl:setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_character")
    end
end

function EMEmployeeFrame:onListSelectionChanged(list, section, index)
    self:displayEmployeeDetails(index)
    self:updateMenuButtons()
end

function EMEmployeeFrame:onSwitchList()
    self.currentListType = self.listSwitcher:getState()
    self:rebuildTable()
end

function EMEmployeeFrame:rebuildTable()
    if g_employeeManager == nil then
        self.employees = {}
    elseif self.currentListType == EMEmployeeFrame.LIST_TYPE.AVAILABLE then
        self.employees = g_employeeManager:getAvailableEmployees()
    else
        self.employees = g_employeeManager:getHiredEmployees()
    end

    self.employeeList:reloadData()

    local hasItems = #self.employees > 0
    if self.mainBox then self.mainBox:setVisible(hasItems) end
    if self.emptyText then self.emptyText:setVisible(not hasItems) end

    if hasItems then
        self.employeeList:setSelectedIndex(1, true, 0)
        self:displayEmployeeDetails(1)
    else
        self:clearDetails()
    end

    if self.txtPoolRefresh then
        if self.currentListType == EMEmployeeFrame.LIST_TYPE.AVAILABLE and g_employeeManager then
            local days = g_employeeManager:getDaysUntilPoolRefresh()
            self.txtPoolRefresh:setVisible(true)
            self.txtPoolRefresh:setText(string.format(g_i18n:getText("em_pool_refresh_in"), days))
        else
            self.txtPoolRefresh:setVisible(false)
        end
    end

    self:updateMenuButtons()
end

function EMEmployeeFrame:displayEmployeeDetails(index)
    local emp = self.employees[index]
    if emp == nil then
        self:clearDetails()
        return
    end

    if self.detailPanel then self.detailPanel:setVisible(true) end

    if self.txtName then self.txtName:setText(emp.name) end
    if self.txtId then self.txtId:setText(string.format("ID: %d", emp.id)) end

    if self.txtStatus then
        local statusKey = emp.isHired and "em_status_hired" or "em_status_available"
        self.txtStatus:setText(g_i18n:getText(statusKey))
    end

    if self.txtTrait then
        local traitName = emp.getTraitName and emp:getTraitName()
        if traitName then
            self.txtTrait:setText(traitName)
        else
            self.txtTrait:setText(g_i18n:getText("em_none"))
        end
    end

    if self.txtAssignedField then
        if emp.targetFieldId then
            self.txtAssignedField:setText(string.format("Field %d", emp.targetFieldId))
        else
            self.txtAssignedField:setText(g_i18n:getText("em_none"))
        end
    end

    self:displaySkills(emp)
    self:displayWorkStats(emp)

    if self.txtWorkflowSummary then
        local queue = emp.taskQueue or {}
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

    if self.txtWage then
        local hourly = emp.getHourlyWage and emp:getHourlyWage() or 0
        local marketMult = 1.0
        if g_employeeManager then
            marketMult = g_employeeManager:getMarketMultiplier()
        end
        local finalWage = hourly * marketMult
        self.txtWage:setText(string.format("%s/h", g_i18n:formatMoney(finalWage, 0, true, false)))
    end

    if self.txtWageBreakdown then
        local base = emp.getBaseHourlyWage and emp:getBaseHourlyWage() or 0
        local traitMult = emp.getTraitMultiplier and emp:getTraitMultiplier("wageMult") or 1.0
        local expMult = math.min(1.25, 1.0 + ((emp.workTime or 0) / 500))
        local marketMult = g_employeeManager and g_employeeManager:getMarketMultiplier() or 1.0
        self.txtWageBreakdown:setText(string.format(
            "%s: $%d | %s: x%.2f | %s: x%.2f | %s: x%.2f",
            g_i18n:getText("em_wage_base"), base,
            g_i18n:getText("em_wage_trait"), traitMult,
            g_i18n:getText("em_wage_exp"), expMult,
            g_i18n:getText("em_wage_market"), marketMult
        ))
    end

    self:displayPerformanceStats(emp)
end

function EMEmployeeFrame:displaySkills(employee)
    local skills  = employee.skills   or { driving = 1, harvesting = 1, technical = 1 }
    local skillXP = employee.skillXP  or { driving = 0, harvesting = 0, technical = 0 }

    local skillDefs = {
        { key = "driving",    starsId = "skillDrivingStars",    xpId = "skillDrivingXP" },
        { key = "harvesting", starsId = "skillHarvestingStars", xpId = "skillHarvestingXP" },
        { key = "technical",  starsId = "skillTechnicalStars",  xpId = "skillTechnicalXP" },
    }

    for _, def in ipairs(skillDefs) do
        local level = math.min(5, math.max(1, skills[def.key] or 1))
        local xp    = skillXP[def.key] or 0
        local xpNeeded = level < 5 and (level * 100) or 0

        local stars = string.rep("*", level) .. string.rep("-", 5 - level)
        local starsText = string.format("[%s] %d/5", stars, level)

        local starsElement = self[def.starsId]
        if starsElement then starsElement:setText(starsText) end

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

function EMEmployeeFrame:displayWorkStats(employee)
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

function EMEmployeeFrame:displayPerformanceStats(employee)
    if self.statTotalWages then
        local total = employee.totalWagesPaid or 0
        self.statTotalWages:setText(g_i18n:formatMoney(total, 0, true, false))
    end

    if self.statTasksCompleted then
        self.statTasksCompleted:setText(tostring(employee.tasksCompleted or 0))
    end

    if self.statAvgWage then
        local hours = employee.workTime or 0
        local total = employee.totalWagesPaid or 0
        if hours > 0 then
            self.statAvgWage:setText(string.format("%s/h", g_i18n:formatMoney(total / hours, 0, true, false)))
        else
            self.statAvgWage:setText("--")
        end
    end

    if self.statEfficiency then
        local hours = employee.workTime or 0
        local tasks = employee.tasksCompleted or 0
        if hours > 0 then
            self.statEfficiency:setText(string.format("%.2f", tasks / hours))
        else
            self.statEfficiency:setText("--")
        end
    end
end

function EMEmployeeFrame:clearDetails()
    if self.detailPanel then self.detailPanel:setVisible(false) end
end

function EMEmployeeFrame:updateMenuButtons()
    local hasSelection = #self.employees > 0 and self.employeeList.selectedIndex > 0

    self.menuButtonInfo = { self.backButtonInfo }

    if self.currentListType == EMEmployeeFrame.LIST_TYPE.AVAILABLE and hasSelection then
        table.insert(self.menuButtonInfo, self.hireButtonInfo)
    elseif self.currentListType == EMEmployeeFrame.LIST_TYPE.HIRED and hasSelection then
        table.insert(self.menuButtonInfo, self.fireButtonInfo)
        table.insert(self.menuButtonInfo, self.editWorkflowButtonInfo)
        table.insert(self.menuButtonInfo, self.trainButtonInfo)
    end

    self:setMenuButtonInfoDirty()
end

function EMEmployeeFrame:getMenuButtonInfo()
    return self.menuButtonInfo
end

function EMEmployeeFrame:getSelectedEmployee()
    local idx = self.employeeList.selectedIndex
    if idx == nil or idx < 1 then return nil end
    return self.employees[idx]
end

function EMEmployeeFrame:onHireEmployee()
    local emp = self:getSelectedEmployee()
    if emp == nil then return end
    YesNoDialog.show(
        function(_, yes)
            if yes then
                g_employeeManager:hireEmployee(emp.id)
                self:rebuildTable()
            end
        end,
        self,
        string.format(g_i18n:getText("em_dialog_hire_yes_no"), emp.name),
        g_i18n:getText("em_dialog_hire_yes_no_btn")
    )
end

function EMEmployeeFrame:onFireEmployee()
    local emp = self:getSelectedEmployee()
    if emp == nil then return end
    YesNoDialog.show(
        function(_, yes)
            if yes then
                g_employeeManager:fireEmployee(emp.id)
                self:rebuildTable()
            end
        end,
        self,
        string.format(g_i18n:getText("em_dialog_fire_yes_no"), emp.name),
        g_i18n:getText("em_dialog_fire_yes_no_btn")
    )
end

function EMEmployeeFrame:onEditWorkflow()
    local emp = self:getSelectedEmployee()
    if emp == nil then return end

    local parentGui = self:getParent()
    while parentGui ~= nil and parentGui.pagingElement == nil do
        parentGui = parentGui:getParent()
    end

    if parentGui and parentGui.pagingElement then
        parentGui.pagingElement:setPage(2)
    end
end

function EMEmployeeFrame:onTrainEmployee()
    local emp = self:getSelectedEmployee()
    if emp == nil then return end

    if g_emTrainingDialog then
        g_emTrainingDialog:setEmployee(emp)
        g_gui:showDialog("EMTrainingDialog")
    end
end
