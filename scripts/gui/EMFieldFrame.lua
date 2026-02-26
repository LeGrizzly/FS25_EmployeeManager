EMFieldFrame = {}

local EMFieldFrame_mt = Class(EMFieldFrame, TabbedMenuFrameElement)

function EMFieldFrame:new()
    local self = TabbedMenuFrameElement.new(nil, EMFieldFrame_mt)
    self.fields         = {}
    self.menuButtonInfo = {}
    return self
end

function EMFieldFrame:copyAttributes(src)
    EMFieldFrame:superClass().copyAttributes(self, src)
end

function EMFieldFrame:initialize()
    self.backButtonInfo = { inputAction = InputAction.MENU_BACK }
    self.menuButtonInfo = { self.backButtonInfo }
end

function EMFieldFrame:onGuiSetupFinished()
    EMFieldFrame:superClass().onGuiSetupFinished(self)
    self.fieldList:setDataSource(self)
    self.fieldList:setDelegate(self)
end

function EMFieldFrame:onFrameOpen()
    EMFieldFrame:superClass().onFrameOpen(self)
    self:rebuildTable()
    self:setSoundSuppressed(true)
    FocusManager:setFocus(self.fieldList)
    self:setSoundSuppressed(false)
end

function EMFieldFrame:onFrameClose()
    EMFieldFrame:superClass().onFrameClose(self)
    self.fields = {}
end

function EMFieldFrame:refresh()
    -- Called by EMGui:onOpen() to pre-load data
end

function EMFieldFrame:getNumberOfSections()
    return 1
end

function EMFieldFrame:getNumberOfItemsInSection(list, section)
    return #self.fields
end

function EMFieldFrame:getTitleForSectionHeader(list, section)
    return ""
end

function EMFieldFrame:populateCellForItemInSection(list, section, index, cell)
    local fieldData = self.fields[index]
    if fieldData == nil then return end

    local titleEl    = cell:getAttribute("title")
    local subtitleEl = cell:getAttribute("subtitle")
    local iconEl     = cell:getAttribute("icon")

    if titleEl then
        titleEl:setText(string.format("Field %d", fieldData.fieldId))
    end
    if subtitleEl then
        subtitleEl:setText(string.format("%.1f ha", fieldData.area))
    end
    if iconEl then
        iconEl:setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_map")
    end
end

function EMFieldFrame:onListSelectionChanged(list, section, index)
    self:displayFieldDetails(index)
    self:updateMenuButtons()
end

function EMFieldFrame:rebuildTable()
    self.fields = self:buildOwnedFieldsList()

    self.fieldList:reloadData()

    local hasItems = #self.fields > 0
    if self.mainBox   then self.mainBox:setVisible(hasItems) end
    if self.emptyText then self.emptyText:setVisible(not hasItems) end

    if hasItems then
        self.fieldList:setSelectedIndex(1, true, 0)
        self:displayFieldDetails(1)
    else
        self:clearDetails()
    end

    self:updateMenuButtons()
end

function EMFieldFrame:buildOwnedFieldsList()
    local fields = {}
    local farmId = g_currentMission:getFarmId()

    if g_fieldManager ~= nil then
        local allFields = {}
        if g_fieldManager.getFields then
            allFields = g_fieldManager:getFields()
        elseif g_fieldManager.fields then
            allFields = g_fieldManager.fields
        end

        for _, field in pairs(allFields) do
            if field ~= nil then
                local owner = nil
                if field.getOwner then
                    owner = field:getOwner()
                elseif field.getFarmland then
                    local farmland = field:getFarmland()
                    if farmland then
                        owner = g_farmlandManager:getFarmlandOwner(farmland.id)
                    end
                end

                if owner == farmId then
                    local fieldId = field.getId and field:getId() or field.fieldId or 0
                    local area = field.getAreaHa and field:getAreaHa() or field.fieldArea or 0
                    table.insert(fields, {
                        fieldId  = fieldId,
                        area     = area,
                        fieldRef = field,
                    })
                end
            end
        end
    end

    table.sort(fields, function(a, b) return a.fieldId < b.fieldId end)
    return fields
end

function EMFieldFrame:displayFieldDetails(index)
    local fieldData = self.fields[index]
    if fieldData == nil then
        self:clearDetails()
        return
    end

    if self.detailPanel then self.detailPanel:setVisible(true) end

    if self.txtFieldId then
        self.txtFieldId:setText(string.format("Field %d", fieldData.fieldId))
    end
    if self.txtFieldArea then
        self.txtFieldArea:setText(string.format("%.2f ha", fieldData.area))
    end

    local cropName, growthText = self:getFieldCropInfo(fieldData.fieldRef)
    if self.txtCurrentCrop then
        self.txtCurrentCrop:setText(cropName)
    end
    if self.txtGrowthState then
        self.txtGrowthState:setText(growthText)
    end

    local conditionText = self:getFieldCondition(fieldData.fieldRef)
    if self.txtFieldCondition then
        self.txtFieldCondition:setText(conditionText)
    end

    local assignedText = self:getAssignedEmployeeText(fieldData.fieldId)
    if self.txtAssignedEmployee then
        self.txtAssignedEmployee:setText(assignedText)
    end
end

function EMFieldFrame:getFieldCropInfo(field)
    if field == nil then return g_i18n:getText("em_none"), "" end

    local fruitTypeIndex = nil
    local growthState = nil

    if field.getFieldStatusAtWorldPosition then
        local x, _, z = field:getCenterOfFieldWorldPosition()
        local data = field:getFieldStatusAtWorldPosition(x, z)
        if data then
            fruitTypeIndex = data.fruitTypeIndex
            growthState = data.growthState
        end
    end

    if fruitTypeIndex == nil and FSDensityMapUtil and FSDensityMapUtil.getFieldCropAtWorldPosition then
        local x, _, z = field:getCenterOfFieldWorldPosition()
        fruitTypeIndex, growthState = FSDensityMapUtil.getFieldCropAtWorldPosition(x, z)
    end

    if fruitTypeIndex == nil or fruitTypeIndex == 0 then
        return g_i18n:getText("em_none"), ""
    end

    if FruitType and FruitType.UNKNOWN and fruitTypeIndex == FruitType.UNKNOWN then
        return g_i18n:getText("em_none"), ""
    end

    local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitType == nil then
        return g_i18n:getText("em_unknown"), ""
    end

    local cropName = fruitType.name or g_i18n:getText("em_unknown")
    local minHarvest = fruitType.minHarvestingGrowthState or 0
    local growthText = string.format("%d / %d", growthState or 0, minHarvest)

    return cropName, growthText
end

function EMFieldFrame:getFieldCondition(field)
    if field == nil then return g_i18n:getText("em_none") end

    if g_employeeManager and g_employeeManager.cropManager then
        local nextStep, reason = g_employeeManager.cropManager:getNextStep(field, nil)
        if nextStep and nextStep ~= "WAIT" then
            return string.format("%s: %s", nextStep, reason or "")
        elseif nextStep == "WAIT" then
            return g_i18n:getText("em_idle")
        end
    end

    return g_i18n:getText("em_none")
end

function EMFieldFrame:getAssignedEmployeeText(fieldId)
    if g_employeeManager == nil then return g_i18n:getText("em_none") end

    local hiredList = g_employeeManager:getHiredEmployees()
    for _, emp in ipairs(hiredList) do
        if emp.targetFieldId == fieldId then
            return emp.name
        end
    end
    return g_i18n:getText("em_none")
end

function EMFieldFrame:clearDetails()
    if self.detailPanel then self.detailPanel:setVisible(false) end
end

function EMFieldFrame:updateMenuButtons()
    self.menuButtonInfo = { self.backButtonInfo }
    self:setMenuButtonInfoDirty()
end

function EMFieldFrame:getMenuButtonInfo()
    return self.menuButtonInfo
end
