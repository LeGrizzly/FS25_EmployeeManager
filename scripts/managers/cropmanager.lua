---@class CropManager
CropManager = {}

local CropManager_mt = Class(CropManager)

function CropManager:new(mission)
    local self = setmetatable({}, CropManager_mt)
    self.mission = mission
    
    -- Knowledge from CSV
    self.crops = {
        WHEAT = { category = "Céréales", fruitType = "WHEAT", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        BARLEY = { category = "Céréales", fruitType = "BARLEY", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        OAT = { category = "Céréales", fruitType = "OAT", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        CANOLA = { category = "Céréales", fruitType = "CANOLA", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        SORGHUM = { category = "Céréales", fruitType = "SORGHUM", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        SOYBEAN = { category = "Céréales", fruitType = "SOYBEAN", steps = {"MULCH", "LIME", "PLOW", "STONES", "FERTILIZE", "SOW", "ROLL", "WEED", "FERTILIZE", "HARVEST"} },
        
        POTATO = { category = "Racines", fruitType = "POTATO", steps = {"MULCH", "LIME", "PLOW", "FERTILIZE", "SOW", "ROLL", "RIDGING", "WEED", "MULCH_LEAVES", "HARVEST"} },
        SUGARBEET = { category = "Racines", fruitType = "SUGARBEET", steps = {"MULCH", "LIME", "PLOW", "FERTILIZE", "SOW", "ROLL", "WEED", "MULCH_LEAVES", "HARVEST"} },
        
        MAIZE = { category = "Spécial", fruitType = "MAIZE", steps = {"PLOW", "SOW", "ROLL", "HARVEST"} },
        SUNFLOWER = { category = "Spécial", fruitType = "SUNFLOWER", steps = {"PLOW", "SOW", "ROLL", "HARVEST"} },
        
        GRASS = { category = "Herbe", fruitType = "GRASS", steps = {"SOW", "ROLL", "FERTILIZE", "MOW", "TEDDER", "WINDROWER"} },
        
        WET_RICE = { category = "Riz", fruitType = "WET_RICE", steps = {"PLOW", "FERTILIZE", "SOW", "HARVEST"} },
        DRY_RICE = { category = "Riz", fruitType = "DRY_RICE", steps = {"PLOW", "FERTILIZE", "SOW", "HARVEST"} }
    }

    CustomUtils:debug("[CropManager] Initialized")
    return self
end

---Determines the next required step for a field based on target crop
---@param field table
---@param targetCropName string
---@return string|nil nextStep, string|nil reason
function CropManager:getNextStep(field, targetCropName)
    local cropData = self.crops[targetCropName]
    if not cropData then return nil, "Unknown crop" end

    -- Ensure field state is valid and updated
    if field.fieldState == nil then
        field.fieldState = FieldState.new()
    end
    
    local x, z = field:getCenterOfFieldWorldPosition()
    field.fieldState:update(x, z)
    
    local state = field.fieldState
    if not state or not state.isValid then 
        -- If update failed to make it valid, try to detect ground type at least
        if state and state.groundType == 0 then
            return nil, "Field state invalid or ground not detected"
        end
    end

    -- Debug: Dump Field State
    CustomUtils:debug("[CropManager] Field %d Analysis for %s:", field.fieldId, targetCropName)
    CustomUtils:debug("  - Fruit: %d (Target: %d)", state.fruitTypeIndex, self:getFruitTypeIndex(targetCropName))
    CustomUtils:debug("  - Growth: %d", state.growthState)
    CustomUtils:debug("  - Plow: %d | Lime: %d | Stones: %d", state.plowLevel, state.limeLevel, state.stoneLevel)
    CustomUtils:debug("  - Stubble: %d | Weed: %d | Spray: %d", state.stubbleShredLevel, state.weedState, state.sprayLevel)

    -- 1. Critical Overrides (Harvest or Wrong Crop)
    -- These take precedence over the workflow because they reset the field
    local targetFruitIndex = self:getFruitTypeIndex(targetCropName)
    
    -- Check for Harvest (Target crop ready)
    if state.fruitTypeIndex == targetFruitIndex and state.growthState > 0 then
        local fruitType = g_fruitTypeManager:getFruitTypeByIndex(state.fruitTypeIndex)
        if fruitType and state.growthState >= fruitType.minHarvestingGrowthState then
            return "HARVEST", "Target crop is ready for harvest"
        elseif state.growthState < fruitType.minHarvestingGrowthState then
            return "WAIT", string.format("Waiting for crop to grow (State: %d/%d)", state.growthState, fruitType.minHarvestingGrowthState)
        end
    end

    -- Check for Wrong Crop (Reset required)
    if state.fruitTypeIndex ~= FruitType.UNKNOWN and state.fruitTypeIndex ~= targetFruitIndex then
        local fruitType = g_fruitTypeManager:getFruitTypeByIndex(state.fruitTypeIndex)
        local fruitName = fruitType and fruitType.name or "UNKNOWN"
        
        -- If wrong crop is ready to harvest, harvest it (profit!)
        if fruitType and state.growthState >= fruitType.minHarvestingGrowthState then
            return "HARVEST", string.format("Harvesting existing %s before planting %s", fruitName, targetCropName)
        else
            -- Otherwise destroy it
            return "PLOW", string.format("Destroying existing %s to plant %s", fruitName, targetCropName)
        end
    end

    -- 2. Strict Workflow Execution
    -- We iterate through the defined steps for this crop. The FIRST step that is "needed" is returned.
    for index, step in ipairs(cropData.steps) do
        local needed, reason = self:checkStepRequirement(step, state, targetCropName)
        if needed then
            CustomUtils:info("[CropManager] Next Step Decided: %s (Reason: %s)", step, reason)
            return step, reason
        end
    end

    return "WAIT", "No workflow steps currently required"
end

---Checks if a specific workflow step is required based on field state
---@param step string
---@param state table
---@param targetCropName string
---@return boolean needed, string reason
function CropManager:checkStepRequirement(step, state, targetCropName)
    if step == "MULCH" then
        -- Mulch if there is stubble (level 0 usually means UNSHREDDED stubble in some maps, check logic)
        -- Assumption: stubbleShredLevel 0 = needs shredding if harvest just happened
        -- But we only mulch if we are NOT going to plow (Plowing handles stubble)
        if state.stubbleShredLevel == 0 and state.fruitTypeIndex == FruitType.UNKNOWN and state.plowLevel == 0 then
            return true, "Stubble detected (No plowing needed)"
        end
    
    elseif step == "PLOW" then
        if state.plowLevel > 0 then return true, "Field requires plowing" end

    elseif step == "LIME" then
        if state.limeLevel > 0 then return true, "Lime level critical" end

    elseif step == "STONES" then
        if state.stoneLevel > 0 then return true, "Stones detected" end

    elseif step == "FERTILIZE" then
        if state.sprayLevel < 1 then return true, "Fertilizer required" end

    elseif step == "SOW" then
        if state.fruitTypeIndex == FruitType.UNKNOWN then
            local canPlant, reason = self:canPlant(targetCropName)
            if canPlant then return true, "Ready to sow" end
            -- If we can't plant, we don't return true (we wait), but we don't skip to next step either?
            -- Actually, if we can't plant, we should probably WAIT.
        end

    elseif step == "ROLL" then
        if state.rollerLevel == 0 and state.growthState == 1 then return true, "Soil needs rolling" end

    elseif step == "WEED" then
        if state.weedState > 0 then return true, "Weeds detected" end
    
    elseif step == "RIDGING" then
         -- Potato/etc logic
         return false, "Not implemented yet"
         
    elseif step == "MULCH_LEAVES" then
         -- Potato haulm topping
         if state.growthState >= 6 then return true, "Ready for haulm topping" end -- Pseudo-check
    end

    return false, nil
end

function CropManager:canPlant(cropName)
    local cropData = self.crops[cropName]
    if not cropData then return false, "Unknown crop" end

    local fruitType = g_fruitTypeManager:getFruitTypeByName(cropData.fruitType)
    if not fruitType then return false, "Fruit type not found" end

    local currentMonth = g_currentMission.environment.currentMonth
    
    -- Check if currentMonth is in planting window
    -- In FS25 fruitType.periodData contains this info
    if fruitType.periodData and fruitType.periodData.plantingPeriods then
        for _, month in ipairs(fruitType.periodData.plantingPeriods) do
            if month == currentMonth then
                return true, "OK"
            end
        end
        return false, "Outside planting window"
    end

    return true, "No period data available" -- Assume true if no calendar (seasonal growth off)
end

function CropManager:getFruitTypeIndex(cropName)
    local cropData = self.crops[cropName]
    if cropData then
        local ft = g_fruitTypeManager:getFruitTypeByName(cropData.fruitType)
        return ft and ft.index or FruitType.UNKNOWN
    end
    return FruitType.UNKNOWN
end
