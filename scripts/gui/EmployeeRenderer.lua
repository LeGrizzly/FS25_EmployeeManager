EmployeeRenderer = {}
EmployeeRenderer_mt = Class(EmployeeRenderer)

function EmployeeRenderer.new(menu)
    CustomUtils:print("[LeftListRenderer] new()")
    local self = {}
    setmetatable(self, EmployeeRenderer_mt)
    self.menu = menu
    self.data = nil
    self.selectedRow = -1
    self.indexChangedCallback = nil
    return self
end

function EmployeeRenderer:setData(data)
    self.data = data
end

function EmployeeRenderer:getNumberOfSections()
    return 1
end

function EmployeeRenderer:getNumberOfItemsInSection(list, section)    
    local menu = self.menu
    if menu == nil then return 0 end

    -- Use pageSwitcher if available (new logic), fallback to employeeDisplaySwitcher (old logic)
    local selection = 1
    if menu.pageSwitcher ~= nil then
        selection = menu.pageSwitcher:getState()
    elseif menu.employeeDisplaySwitcher ~= nil then
        selection = menu.employeeDisplaySwitcher:getState()
    end

    if self.data == nil or self.data[selection] == nil then
        return 0
    end

    return #self.data[selection]
end

function EmployeeRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function EmployeeRenderer:populateCellForItemInSection(list, section, index, cell)
    local menu = self.menu
    if menu == nil then return end
    
    local selection = 1
    if menu.pageSwitcher ~= nil then
        selection = menu.pageSwitcher:getState()
    elseif menu.employeeDisplaySwitcher ~= nil then
        selection = menu.employeeDisplaySwitcher:getState()
    end
    
    local item = self.data[selection][index]

    if item ~= nil then
        -- Detect Item Type
        if item.skills ~= nil then
            -- It's an Employee
            cell:getAttribute("icon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_character")
            cell:getAttribute("title"):setText(item.name)
            
            local wage = item.getDailyWage and item:getDailyWage() or 0
            cell:getAttribute("subtitle"):setText(g_i18n:formatMoney(wage, 0, true, true))
            
            if item.assignedVehicleId then
                 cell:getAttribute("extra"):setText("Vehicle Assigned")
            else
                 cell:getAttribute("extra"):setText("")
            end
        elseif item.area ~= nil then
            -- It's a Field
            cell:getAttribute("icon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_map") -- Or similar map icon
            cell:getAttribute("title"):setText(item.name) -- "Field 30"
            cell:getAttribute("subtitle"):setText(string.format("%.2f ha", item.area))
            cell:getAttribute("extra"):setText("")
        else
            -- Fallback
            cell:getAttribute("title"):setText("Unknown Item")
        end
    end
end

function EmployeeRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
