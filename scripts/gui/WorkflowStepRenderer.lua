WorkflowStepRenderer = {}
local WorkflowStepRenderer_mt = Class(WorkflowStepRenderer)

function WorkflowStepRenderer.new(menu)
    local self = {}
    setmetatable(self, WorkflowStepRenderer_mt)
    self.menu = menu
    self.steps = {} -- List of steps e.g. {"PLOW", "LIME"}
    self.assignments = {} -- stepIndex -> employeeId
    return self
end

function WorkflowStepRenderer:setSteps(steps, assignments)
    self.steps = steps or {}
    self.assignments = assignments or {}
end

function WorkflowStepRenderer:getNumberOfSections()
    return 1
end

function WorkflowStepRenderer:getNumberOfItemsInSection(list, section)
    return #self.steps
end

function WorkflowStepRenderer:populateCellForItemInSection(list, section, index, cell)
    local stepName = self.steps[index]
    
    -- Set Step Name
    cell:getAttribute("stepName"):setText(stepName)
    
    -- Setup Assignee Selector
    local selector = cell:getAttribute("assigneeSelector")
    if selector then
        local texts = {"Auto-Assign"}
        local hired = g_employeeManager:getHiredEmployees()
        for _, emp in ipairs(hired) do
            table.insert(texts, emp.name)
        end
        selector:setTexts(texts)
        
        -- Restore selection if exists
        local currentAssigneeId = self.assignments[index]
        if currentAssigneeId then
            -- Find index in texts list... (simplified logic needed here)
            -- For now, default to Auto-Assign (index 1)
            selector:setState(1) 
        end
        
        -- Callback for change
        selector:setCallback(function(sender, state)
            self:onAssigneeChanged(index, state)
        end)
    end
    
    -- Status Icon (Placeholder)
    cell:getAttribute("statusIcon"):setImageSlice(g_gui.sharedGuiAtlas, "ingameMenu/tab_overview") 
end

function WorkflowStepRenderer:onAssigneeChanged(stepIndex, state)
    -- Map state index back to employee ID
    -- State 1 = Auto, State 2 = Hired[1], etc.
    if state == 1 then
        self.assignments[stepIndex] = nil -- Auto
    else
        local hired = g_employeeManager:getHiredEmployees()
        local emp = hired[state - 1]
        if emp then
            self.assignments[stepIndex] = emp.id
            CustomUtils:info("[Workflow] Assigned step %d to %s", stepIndex, emp.name)
        end
    end
end
