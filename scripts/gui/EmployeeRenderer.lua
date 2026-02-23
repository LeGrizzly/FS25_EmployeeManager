--[[
    EmployeeRenderer.lua
    PR Fix: Cell attribute names must match the <ListItem> child "name="
    values defined in MenuEmployeeManager.xml.
    Old XML used: "employeeIcon" / "name" / "wage"
    New XML uses:  "icon"        / "title" / "subtitle"
    Also: pageSwitcher reference replaces old employeeDisplaySwitcher.
]]

EmployeeRenderer = {}
EmployeeRenderer_mt = Class(EmployeeRenderer)

function EmployeeRenderer.new(menu)
    local self = setmetatable({}, EmployeeRenderer_mt)
    self.menu                 = menu
    self.data                 = nil
    self.selectedRow          = -1
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

    -- pageSwitcher is the correct element ID in the fixed XML
    local selection = 1
    if menu.pageSwitcher ~= nil then
        selection = menu.pageSwitcher:getState()
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
    end

    if self.data == nil or self.data[selection] == nil then return end
    local item = self.data[selection][index]
    if item == nil then return end

    -- Use names that match the XML <ListItem> template:
    --   name="icon"     → Bitmap
    --   name="title"    → primary Text
    --   name="subtitle" → secondary Text (was "wage" / "info" in old XML)

    if item.skills ~= nil then
        -- ── Employee row ──
        cell:getAttribute("icon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_character")
        cell:getAttribute("title"):setText(item.name)

        local wage = item.getDailyWage and item:getDailyWage() or 0
        cell:getAttribute("subtitle"):setText(g_i18n:formatMoney(wage, 0, true, true))

    elseif item.area ~= nil then
        -- ── Field row ──
        cell:getAttribute("icon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_map")
        cell:getAttribute("title"):setText(item.name)
        cell:getAttribute("subtitle"):setText(string.format("%.2f ha", item.area))

    else
        -- Fallback
        cell:getAttribute("title"):setText("?")
        cell:getAttribute("subtitle"):setText("")
    end
end

function EmployeeRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
