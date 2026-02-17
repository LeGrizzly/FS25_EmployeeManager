MenuEmployeeManager = {}

MenuEmployeeManager.CLASS_NAME = 'MenuEmployeeManager'
MenuEmployeeManager.MENU_PAGE_NAME = 'menuEmployeeManager'
MenuEmployeeManager.XML_FILENAME = g_modDirectory .. 'xml/gui/MenuEmployeeManager.xml'
MenuEmployeeManager.MENU_ICON_SLICE_ID = 'employeeManager.menuIcon'
MenuEmployeeManager._mt = Class(MenuEmployeeManager, TabbedMenuFrameElement)

MenuEmployeeManager.LIST_TYPE = {
    NEW = 1,
    ACTIVE = 2,
    OWNED = 3
}
MenuEmployeeManager.LIST_STATE_TEXTS = { "em_list_new", "em_list_active", "em_list_owned" }
MenuEmployeeManager.HEADER_TITLE = "em_header_employees"

function MenuEmployeeManager.new(i18n, messageCenter)
    EmployeeUtils.debugPrint("[MenuEmployeeManager] new()")
    local self = MenuEmployeeManager:superClass().new(nil, MenuEmployeeManager._mt)
    self.name = "MenuEmployeeManager"
    self.className = "MenuEmployeeManager" -- For identifying in renderer
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.menuButtonInfo = {}
    self.employeeRenderer = EmployeeRenderer.new(self)
    return self
end

function MenuEmployeeManager:displaySelectedEmployee()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] displaySelectedEmployee()")
    local index = self.employeesTable.selectedIndex
    if index == -1 or index == 0 then
        self.employeeInfoContainer:setVisible(false)
        self.noSelectedEmployeeText:setVisible(true)
        return
    end

    local selection = self.employeeDisplaySwitcher:getState()
    local employee = self.employeeRenderer.data[selection][index]

    if employee ~= nil then
        self.employeeInfoContainer:setVisible(true)
        self.noSelectedEmployeeText:setVisible(false)
        self.employeeName:setText(employee.name)
        self.employeeId:setText(string.format(g_i18n:getText("em_employee_id_label"), employee.id))
        self.employeeWageValue:setText(g_i18n:formatMoney(employee:getDailyWage(), 0, true, true))
        local statusText = employee.isHired and g_i18n:getText("em_status_hired") or g_i18n:getText("em_status_available")
        self.employeeStatusValue:setText(statusText)
        self.employeeSkillsValue:setText(string.format("Driving: %d | Harvesting: %d | Technical: %d", employee.skills.driving or 0, employee.skills.harvesting or 0, employee.skills.technical or 0))
    else
        self.employeeInfoContainer:setVisible(false)
        self.noSelectedEmployeeText:setVisible(true)
    end
end

function MenuEmployeeManager:onGuiSetupFinished()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onGuiSetupFinished()")
    MenuEmployeeManager:superClass().onGuiSetupFinished(self)
    self.employeesTable:setDataSource(self.employeeRenderer)
    self.employeesTable:setDelegate(self.employeeRenderer)
    self.employeeRenderer.indexChangedCallback = function(index)
        EmployeeUtils.debugPrint("[MenuEmployeeManager] onGuiSetupFinished() -> indexChangedCallback()")
        self:displaySelectedEmployee()
        self:updateMenuButtons()
    end
end

function MenuEmployeeManager:initialize()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] initialize()")
    MenuEmployeeManager:superClass().initialize(self)
    local employeeSwitcherTexts = {}
    for _, textKey in ipairs(MenuEmployeeManager.LIST_STATE_TEXTS) do
        table.insert(employeeSwitcherTexts, g_i18n:getText(textKey))
    end
    self.employeeDisplaySwitcher:setTexts(employeeSwitcherTexts)

    self.btnBack = { inputAction = InputAction.MENU_BACK }
    self.btnHire = { inputAction = InputAction.MENU_ACCEPT, text = g_i18n:getText("em_btn_hire"), callback = function() self:onHireEmployee() end }
    self.btnFire = { inputAction = InputAction.MENU_EXTRA_2, text = g_i18n:getText("em_btn_fire"), callback = function() self:onFireEmployee() end }
    self.btnAssign = { inputAction = InputAction.MENU_EXTRA_1, text = g_i18n:getText("em_btn_assign"), callback = function() self:onAssignVehicle() end }
    -- self.btnUnassign = { inputAction = InputAction.MENU_EXTRA_2, text = g_i18n:getText("em_btn_unassign"), callback = function() self:onUnassignVehicle() end }

    self.employeeButtonSets = {}
    
    -- NEW (Available to hire)
    self.employeeButtonSets[MenuEmployeeManager.LIST_TYPE.NEW] = { self.btnBack, self.btnHire }
    
    -- ACTIVE (Working)
    self.employeeButtonSets[MenuEmployeeManager.LIST_TYPE.ACTIVE] = { self.btnBack, self.btnAssign } -- Add Unassign later
    
    -- OWNED (Hired)
    self.employeeButtonSets[MenuEmployeeManager.LIST_TYPE.OWNED] = { self.btnBack, self.btnFire, self.btnAssign }
    
    self.currentEmployeeListType = self.employeeDisplaySwitcher:getState() or MenuEmployeeManager.LIST_TYPE.NEW
    self:updateMenuButtons()
end

function MenuEmployeeManager:getMenuButtonInfo()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] getMenuButtonInfo()")
    return self.menuButtonInfo.employees or { self.btnBack }
end

function MenuEmployeeManager:onFrameOpen()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onFrameOpen()")
    MenuEmployeeManager:superClass().onFrameOpen(self)
    self:onMoneyChange()
    g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_ADDED, self.updateContent, self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_REMOVED, self.updateContent, self)
    self:updateContent()
end

function MenuEmployeeManager:onFrameClose()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onFrameClose()")
    MenuEmployeeManager:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuEmployeeManager:onSwitchEmployeeDisplay()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onSwitchEmployeeDisplay()")
    self.currentEmployeeListType = self.employeeDisplaySwitcher:getState()
    self:updateContent()
end

function MenuEmployeeManager:updateContent()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] updateContent()")
    self.categoryHeaderText:setText(g_i18n:getText(MenuEmployeeManager.HEADER_TITLE))

    if g_employeeManager == nil then
        Logging.warning("[MenuEmployeeManager] g_employeeManager is nil. No data to display.")
        self.employeeRenderer:setData({
            [MenuEmployeeManager.LIST_TYPE.NEW] = {},
            [MenuEmployeeManager.LIST_TYPE.ACTIVE] = {},
            [MenuEmployeeManager.LIST_TYPE.OWNED] = {},
        })
        self.employeesTable:reloadData()
        self.employeesContainer:setVisible(false)
        self.employeeInfoContainer:setVisible(false)
        self.noEmployeesContainer:setVisible(true)
        return
    end

    local available = g_employeeManager:getAvailableEmployees()
    local hired = g_employeeManager:getHiredEmployees()
    
    print("--- Available Employees ---")
    for _, e in ipairs(available) do
        print(string.format("ID: %d, Name: %s, Daily Wage: %d", e.id, e.name, e:getDailyWage()))
    end
    print("---------------------------")

    local active = {}
    for _, e in ipairs(hired) do
        if e.currentJob ~= nil then
            table.insert(active, e)
        end
    end

    local renderData = {
        [MenuEmployeeManager.LIST_TYPE.NEW] = available,
        [MenuEmployeeManager.LIST_TYPE.ACTIVE] = active,
        [MenuEmployeeManager.LIST_TYPE.OWNED] = hired,
    }

    self.employeeRenderer:setData(renderData)
    self.employeesTable:reloadData()
    local hasItem = self.employeesTable:getItemCount() > 0
    self.employeesContainer:setVisible(hasItem)
    self.employeeInfoContainer:setVisible(hasItem)
    self.noEmployeesContainer:setVisible(not hasItem)

    self.employeesTable:setSelectedIndex(hasItem and 1 or 0)
    self:displaySelectedEmployee()
    self:updateMenuButtons()
    self:setMenuButtonInfoDirty()
end

function MenuEmployeeManager:updateMenuButtons()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] updateMenuButtons()")

    -- Guard against being called before fully initialized
    if self.employeeButtonSets == nil or self.menuButtonInfo == nil then
        return
    end

    local listType = self.currentEmployeeListType or MenuEmployeeManager.LIST_TYPE.NEW
    local baseButtons = self.employeeButtonSets[listType] or { self.btnBack }
    local employee = self:getSelectedEmployee()
    local filtered = {}
    for _, btn in ipairs(baseButtons) do
        if self:shouldShowButton(btn, listType, employee) then
            table.insert(filtered, btn)
        end
    end
    self.menuButtonInfo.employees = filtered
    self:setMenuButtonInfoDirty()
end

function MenuEmployeeManager:getSelectedEmployee()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] getSelectedEmployee()")
    local index = self.employeesTable.selectedIndex
    if index == nil or index < 1 then return nil end
    local selection = self.employeeDisplaySwitcher:getState()
    local list = self.employeeRenderer.data and self.employeeRenderer.data[selection]
    if list == nil then return nil end
    return list[index]
end

function MenuEmployeeManager:shouldShowButton(button, listType, employee)
    EmployeeUtils.debugPrint("[MenuEmployeeManager] shouldShowButton()")
    if button == self.btnBack then return true end
    return employee ~= nil
end

function MenuEmployeeManager:onMoneyChange()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onMoneyChange()")
    if g_localPlayer ~= nil then
        local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
        self.currentBalanceText:applyProfile(farm.money <= -1 and ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE or ShopMenu.GUI_PROFILE.SHOP_MONEY, nil, true)
        self.currentBalanceText:setText(g_i18n:formatMoney(farm.money, 0, true, false))
        if self.shopMoneyBox ~= nil then
        self.shopMoneyBox:invalidateLayout()
        self.shopMoneyBoxBg:setSize(self.shopMoneyBox.flowSizes[1] + 60 * g_pixelSizeScaledX)
        end
    end
end

function MenuEmployeeManager:onHireEmployee()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onHireEmployee()")
    local employee = self:getSelectedEmployee()
    if employee == nil then return end
    YesNoDialog.show(function(_, yes) if yes then g_employeeManager:hireEmployee(employee.id) self:updateContent() end end, self, string.format(g_i18n:getText("em_dialog_hire_yes_no"), employee.name), g_i18n:getText("em_dialog_hire_yes_no_btn"))
end

function MenuEmployeeManager:onFireEmployee()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onFireEmployee()")
    local employee = self:getSelectedEmployee()
    if employee == nil then return end
    YesNoDialog.show(function(_, yes) if yes then g_employeeManager:fireEmployee(employee.id) self:updateContent() end end, self, string.format(g_i18n:getText("em_dialog_fire_yes_no"), employee.name), g_i18n:getText("em_dialog_fire_yes_no_btn"))
end

function MenuEmployeeManager:onAssignVehicle()
    EmployeeUtils.debugPrint("[MenuEmployeeManager] onAssignVehicle()")
    local employee = self:getSelectedEmployee()
    if employee == nil then return end
    InfoDialog.show(string.format("Assign vehicle to %s (Not Implemented)", employee.name))
end
