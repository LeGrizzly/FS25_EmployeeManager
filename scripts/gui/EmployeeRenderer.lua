EmployeeRenderer = {}
EmployeeRenderer_mt = Class(EmployeeRenderer)

function EmployeeRenderer.new(menu)
    CustomUtils:print("[EmployeeRenderer] new()")
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
    if menu == nil then
        return 0
    end

    local selection = 1 -- Default
    if menu.employeeDisplaySwitcher ~= nil then
        selection = menu.employeeDisplaySwitcher:getState()
    else
        CustomUtils:print("[EmployeeRenderer] getNumberOfItemsInSection() employeeDisplaySwitcher not found, defaulting to 1")
    end

    if self.data == nil then
        return 0
    end

    if self.data[selection] == nil then
        return 0
    end

    return #self.data[selection]
end

function EmployeeRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function EmployeeRenderer:populateCellForItemInSection(list, section, index, cell)
    CustomUtils:print("[EmployeeRenderer] populateCellForItemInSection(index: %s)", tostring(index))
    
    local menu = self.menu
    if menu == nil then return end
    
    local selection = 1
    if menu.employeeDisplaySwitcher ~= nil then
        selection = menu.employeeDisplaySwitcher:getState()
    end
    
    local employee = self.data[selection][index]

    if employee ~= nil then
        cell:getAttribute("employeeIcon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_character")
        cell:getAttribute("name"):setText(employee.name)

        cell:getAttribute("wage"):setText(tostring(employee.id)) -- Debug: Show ID
    end
end

function EmployeeRenderer:onListSelectionChanged(list, section, index)
    CustomUtils:print("[EmployeeRenderer] onListSelectionChanged(index: %s)", tostring(index))
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
