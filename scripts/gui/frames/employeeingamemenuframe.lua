---@class InGameMenuEmployeeManagerFrame : TabbedMenuFrameElement
---@field isOpen boolean
---@field lastUpdate number
---@field backButtonInfo table
---@field frameSliderBox ThreePartBitmapElement
---@field frameSlider SliderElement
---@field employees Employee[]
---@field list SmoothListElement
---@field detailBox GuiElement
---@field itemDetailsImage BitmapElement
---@field itemDetailsName TextElement
---@field superClass fun(): TabbedMenuFrameElement
InGameMenuEmployeeManagerFrame = {}

InGameMenuEmployeeManagerFrame.CLASS_NAME = 'InGameMenuEmployeeManagerFrame'
InGameMenuEmployeeManagerFrame.MENU_PAGE_NAME = 'ingameMenuEmployeeManager'
-- InGameMenuEmployeeManagerFrame.MENU_ICON_SLICE_ID = '' -- TODO: Change icon
InGameMenuEmployeeManagerFrame.XML_FILENAME = g_currentModDirectory .. 'xml/gui/frames/employeeingamemenuframe.xml'
InGameMenuEmployeeManagerFrame.UPDATE_INTERVAL = 4000

InGameMenuEmployeeManagerFrame.L10N_STATUS_AVAILABLE = g_i18n:getText('em_status_available')
InGameMenuEmployeeManagerFrame.L10N_STATUS_WORKING = g_i18n:getText('em_status_working')

InGameMenuEmployeeManagerFrame.L10N_ACTION_HIRE = g_i18n:getText('em_action_hire')
InGameMenuEmployeeManagerFrame.L10N_ACTION_FIRE = g_i18n:getText('em_action_fire')
InGameMenuEmployeeManagerFrame.L10N_ACTION_ASSIGN_VEHICLE = g_i18n:getText('em_action_assign_vehicle')
InGameMenuEmployeeManagerFrame.L10N_ACTION_ASSIGN_JOB = g_i18n:getText('em_action_assign_job')


local InGameMenuEmployeeManagerFrame_mt = Class(InGameMenuEmployeeManagerFrame, TabbedMenuFrameElement)

---@return InGameMenuEmployeeManagerFrame
function InGameMenuEmployeeManagerFrame.new()
    local self = TabbedMenuFrameElement.new(nil, InGameMenuEmployeeManagerFrame_mt)
    ---@cast self InGameMenuEmployeeManagerFrame

    self.isOpen = false
    self.lastUpdate = 0
    self.employees = {}

    self.hasCustomMenuButtons = true

    return self
end

function InGameMenuEmployeeManagerFrame:delete()
    self:superClass().delete(self)
    g_messageCenter:unsubscribeAll(self)
end

function InGameMenuEmployeeManagerFrame:initialize()
    self.nextPageButtonInfo = {
        ["inputAction"] = InputAction.MENU_PAGE_NEXT,
        ["text"] = g_i18n:getText("ui_ingameMenuNext"),
        ["callback"] = self.onPageNext
    }

    self.prevPageButtonInfo = {
        ["inputAction"] = InputAction.MENU_PAGE_PREV,
        ["text"] = g_i18n:getText("ui_ingameMenuPrev"),
        ["callback"] = self.onPagePrevious
    }

    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }

    self.hireButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_2,
        text = InGameMenuEmployeeManagerFrame.L10N_ACTION_HIRE,
        callback = function ()
            self:onClickHire()
        end
    }
    
    self.fireButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_1,
        text = InGameMenuEmployeeManagerFrame.L10N_ACTION_FIRE,
        callback = function ()
            self:onClickFire()
        end
    }

    if self.list ~= nil and type(self.list.setDataSource) == 'function' then
        self.list:setDataSource(self)
    else
        Logging.warning("[%s] GUI list element not yet available when initializing InGameMenuEmployeeManagerFrame", InGameMenuEmployeeManagerFrame.CLASS_NAME)
    end
end

function InGameMenuEmployeeManagerFrame:onGuiSetupFinished()
    self:superClass().onGuiSetupFinished(self)
    self:initialize()
end

function InGameMenuEmployeeManagerFrame:getMenuButtonInfo()
    return self.menuButtonInfo
end

function InGameMenuEmployeeManagerFrame:onFrameOpen()
    self:superClass().onFrameOpen(self)
    self.isOpen = true
    self:updateEmployees()
    FocusManager:setFocus(self.list)
    self.detailBox:setVisible(#self.employees > 0)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_ADDED, self.onEmployeeAdded, self)
    g_messageCenter:subscribe(MessageType.EMPLOYEE_REMOVED, self.onEmployeeRemoved, self)
end

function InGameMenuEmployeeManagerFrame:onFrameClose()
    self.isOpen = false
    g_messageCenter:unsubscribeAll(self)
    self:superClass().onFrameClose(self)
end

---@param dt number
function InGameMenuEmployeeManagerFrame:update(dt)
    self:superClass().update(self, dt)
    if self.isOpen then
        self.lastUpdate = self.lastUpdate + dt
        if self.lastUpdate > InGameMenuEmployeeManagerFrame.UPDATE_INTERVAL then
            self:updateEmployees()
        end
    end
end

function InGameMenuEmployeeManagerFrame:updateEmployees()
    if g_employeeManager == nil then
        return
    end
    self.employees = g_employeeManager:getEmployees()
    table.sort(self.employees, function (a, b)
        return a:getName() < b:getName()
    end)
    self.list:reloadData()
    self:updateEmployeeDetails()
    self:updateMenuButtons()
    self.lastUpdate = 0
end

---@param list SmoothListElement
---@param section number
---@return number
function InGameMenuEmployeeManagerFrame:getNumberOfItemsInSection(list, section)
    return #self.employees
end

---@param list SmoothListElement
---@param section number
---@param index number
---@param cell table
function InGameMenuEmployeeManagerFrame:populateCellForItemInSection(list, section, index, cell)
    local employee = self.employees[index]
    if employee ~= nil then
        cell:getAttribute('name'):setText(employee:getFullName())
        cell:getAttribute('skillDriving'):setText(tostring(employee.skills.driving))
        cell:getAttribute('skillHarvesting'):setText(tostring(employee.skills.harvesting))
        cell:getAttribute('skillTechnical'):setText(tostring(employee.skills.technical))
        cell:getAttribute('assignedVehicle'):setText(employee.assignedVehicle or "-")
        cell:getAttribute('currentJob'):setText(employee.currentJob or "-")
        cell:getAttribute('status'):setText(employee.isWorking and InGameMenuEmployeeManagerFrame.L10N_STATUS_WORKING or InGameMenuEmployeeManagerFrame.L10N_STATUS_AVAILABLE)
    else
        Logging.error("Unable to find employee entry index: %d", index)
    end
end

---@param list SmoothListElement
---@param section number
---@param index number
function InGameMenuEmployeeManagerFrame:onListSelectionChanged(list, section, index)
    self:updateEmployeeDetails()
    self:updateMenuButtons()
end

function InGameMenuEmployeeManagerFrame:updateMenuButtons()
    self.menuButtonInfo = {
        self.backButtonInfo,
        self.nextPageButtonInfo,
        self.prevPageButtonInfo,
        self.hireButtonInfo,
    }
    local employee = self:getSelectedEmployee()
    if employee ~= nil then
        table.insert(self.menuButtonInfo, self.fireButtonInfo)
    end
    self:setMenuButtonInfoDirty()
end

function InGameMenuEmployeeManagerFrame:updateEmployeeDetails()
    local employee = self:getSelectedEmployee()
    if employee ~= nil then
        self.detailBox:setVisible(true)
        -- self.itemDetailsImage:setImageFilename(employee:getImageFilename()) -- TODO: Add employee image
        self.itemDetailsName:setText(employee:getFullName())
    else
        self.detailBox:setVisible(false)
    end
end

---@return Employee | nil
---@nodiscard
function InGameMenuEmployeeManagerFrame:getSelectedEmployee()
    if self.list ~= nil then
        return self.employees[self.list:getSelectedIndexInSection()]
    end
end

function InGameMenuEmployeeManagerFrame:onEmployeeAdded()
    self:updateEmployees()
end

function InGameMenuEmployeeManagerFrame:onEmployeeRemoved()
    self:updateEmployees()
end

function InGameMenuEmployeeManagerFrame:onClickHire()
    g_employeeManager:hireEmployee("New Employee", {driving=1, harvesting=1, technical=1})
end

function InGameMenuEmployeeManagerFrame:onClickFire()
    local employee = self:getSelectedEmployee()
    if employee ~= nil then
        g_employeeManager:fireEmployee(employee.id)
    end
end

function InGameMenuEmployeeManagerFrame:onItemDoubleClick()
    -- Open detail screen for selected employee
end
