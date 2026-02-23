AIOverrideExtension = {}

function AIOverrideExtension.init()
    local mission = g_currentMission
    if mission ~= nil then
        -- Hook into AIVehicle to intercept toggleAI action
        AIOverrideExtension.hookSpecialization("aiVehicle")
        -- Hook into AIJobVehicle for the H key (Standard AI)
        AIOverrideExtension.hookSpecialization("aiJobVehicle")
    end
end

function AIOverrideExtension.hookSpecialization(specName)
    local spec = g_specializationManager:getSpecializationByName(specName)
    if spec == nil then return end

    -- Override registerActionEvents to replace standard AI toggle
    local originalRegisterActionEvents = spec.registerActionEvents
    if originalRegisterActionEvents == nil then return end
    
    spec.registerActionEvents = function(self, isActive, ...)
        -- Call original to register other events
        originalRegisterActionEvents(self, isActive, ...)
        
        if isActive then
            -- Remove default TOGGLE_AI if present
            local specData = self["spec_" .. specName]
            if specData and specData.actionEvents then
                local actionEvent = specData.actionEvents[InputAction.TOGGLE_AI]
                if actionEvent ~= nil then
                    g_inputBinding:removeActionEvent(actionEvent.actionEventId)
                end
            end
            
            -- Register our own TOGGLE_AI handler
            local _, eventId = g_inputBinding:registerActionEvent(InputAction.TOGGLE_AI, self, AIOverrideExtension.onToggleAI, false, true, false, true)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
            g_inputBinding:setActionEventText(eventId, g_i18n:getText("action_toggleEmployeeAI") or "Hire/Dismiss Employee")
        end
    end
end

function AIOverrideExtension.onToggleAI(vehicle, actionName, inputValue, callbackState, isAnalog)
    if vehicle == nil then return end

    -- Check if we already have an assigned employee for this vehicle
    local employee = g_employeeManager:getEmployeeByVehicle(vehicle)
    
    if employee ~= nil then
        -- Employee exists: toggle their work state
        if employee.currentJob ~= nil or vehicle:getIsAIActive() then
            -- Stop current job
            g_employeeManager:consoleStopJob(employee.id)
            g_currentMission:showBlinkingWarning(string.format("Employee %s stopped.", employee.name), 2000)
        else
            -- If idling, open manager menu to give orders
            g_gui:showGui("MenuEmployeeManager")
        end
    else
        -- No employee assigned: Open the manager menu to hire/assign one
        g_gui:showGui("MenuEmployeeManager")
        g_currentMission:showBlinkingWarning("No employee assigned to this vehicle!", 2000)
    end
end
