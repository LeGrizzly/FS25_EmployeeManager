JobManager = {}

JobManager.WORK_TYPE_TO_CATEGORY = {
    PLOW = "PLOWS",
    CULTIVATE = "CULTIVATORS",
    SOW = "SEEDERS",
    HARVEST = "COMBINES",
    MOW = "MOWERS",
    FERTILIZE = "SPRAYERS",
    LIME = "SALT_SPREADERS",
    MULCH = "MULCHERS",
    STONES = "STONE_PICKERS",
    ROLL = "ROLLERS",
    WEED = "WEEDERS",
    RIDGING = "PLANTERS",
    MULCH_LEAVES = "MULCHERS",
    TEDDER = "TEDDERS",
    WINDROWER = "WINDROWERS"
}

local JobManager_mt = Class(JobManager)

---@param mission table
---@return JobManager
function JobManager:new(mission)
    local self = setmetatable({}, JobManager_mt)
    self.mission = mission
    self.activeJobs = {}

    CustomUtils:debug("[JobManager] Initialized")
    return self
end

---Starts a field work job for an employee with 100% autonomy
---@param employee table
---@param fieldId number
---@param workType string (e.g. "PLOW", "SOW", "HARVEST")
---@return boolean Success
function JobManager:startFieldWork(employee, fieldId, workType)
    CustomUtils:info("[JobManager] Attempting to start job for %s on Field %d (%s)", employee.name, fieldId, workType)

    if not employee or not employee.isHired then
        CustomUtils:error("[JobManager] Invalid employee or employee not hired")
        return false
    end

    local vehicle = g_employeeManager:getVehicleById(employee.assignedVehicleId)
    if not vehicle then
        CustomUtils:error("[JobManager] No assigned vehicle for employee %s", employee.name)
        return false
    end

    local field = g_fieldManager:getFieldById(fieldId)
    if not field then
        CustomUtils:error("[JobManager] Field ID %d not found", fieldId)
        return false
    end

    if workType == "HARVEST" then
        if not vehicle.spec_combine then
            local msg = string.format("Employee %s cannot harvest with a %s. A self-propelled harvester is required.",
                employee.name, vehicle:getName())
            CustomUtils:error("[JobManager] " .. msg)
            g_currentMission:showBlinkingWarning(msg, 5000)
            return false
        end
    end

    local req = EMWorkflowFrame.TASK_REQUIREMENTS[workType]
    if req then
        local level = employee.skills[req.skill] or 1
        if level < req.level then
            CustomUtils:error("[JobManager] Employee %s does not have enough %s skill for %s (Current: %d, Required: %d)",
                employee.name, req.skill, workType, level, req.level)
            return false
        end
    end

    employee.currentJob = {
        type = "PREPARING",
        fieldId = fieldId,
        workType = workType
    }

    CustomUtils:debug("[JobManager] Preparing vehicle %s (ID: %d) for job...", vehicle:getName(), vehicle.id)

    if vehicle.startMotor and not vehicle:getIsMotorStarted() then
        CustomUtils:debug("[JobManager] Starting motor for %s", vehicle:getName())
        vehicle:startMotor()
    end
    if vehicle.setBrakePedalInput then
        vehicle:setBrakePedalInput(0)
    end
    if vehicle.setCruiseControlState then
        vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
    end

    if vehicle.stopAIJob then
        CustomUtils:debug("[JobManager] Stopping any existing AI job")
        vehicle:stopAIJob()
    end

    self:ensureEquipment(vehicle, workType, function(success)
        if not success then
            CustomUtils:error("[JobManager] Could not ensure equipment for %s - Job Aborted", workType)
            employee.currentJob = nil
            return
        end

        CustomUtils:debug("[JobManager] Equipment ensured. Check distance...")

        local x, z = field:getCenterOfFieldWorldPosition()
        local vx, _, vz = getWorldTranslation(vehicle.rootNode)
        local distance = MathUtil.vector2Length(vx - x, vz - z)

        CustomUtils:info("[JobManager] Distance to Field %d: %.1f m", fieldId, distance)

        if distance > 150 then
            CustomUtils:info("[JobManager] Field is far. Starting TRANSIT (GOTO) job first.")

            local aiJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.GOTO)
            if aiJob then
                local farmId = g_currentMission:getFarmId()
                aiJob:applyCurrentState(vehicle, g_currentMission, farmId, false)
                aiJob.positionAngleParameter:setPosition(x, z)

                local dx, dz = x - vx, z - vz
                local angle = MathUtil.getYRotationFromDirection(dx, dz)
                aiJob.positionAngleParameter:setAngle(angle)

                aiJob:setValues()

                local validateSuccess, errorMessage = aiJob:validate(farmId)
                if validateSuccess then
                    g_currentMission.aiSystem:startJob(aiJob, farmId)

                    employee.currentJob = {
                        aiJobId = aiJob.jobId,
                        type = "TRANSIT",
                        fieldId = fieldId,
                        workType = workType,
                        startTime = g_currentMission.time
                    }

                    employee.pendingJob = {
                        fieldId = fieldId,
                        workType = workType
                    }
                    CustomUtils:info("[JobManager] Employee %s is now in TRANSIT to field %d", employee.name, fieldId)
                    return
                else
                    CustomUtils:error("[JobManager] Transit GOTO job failed validation: %s", errorMessage)
                end
            else
                CustomUtils:error("[JobManager] Failed to create GOTO job")
            end
        end

        CustomUtils:debug("[JobManager] Starting FIELDWORK immediately (Direct or Close Proximity).")
        self:startFieldWorkJob(employee, vehicle, fieldId, workType)
    end)

    return true
end

---Internal helper to start the actual fieldwork job
function JobManager:startFieldWorkJob(employee, vehicle, fieldId, workType)
    local aiJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK)
    if not aiJob then 
            CustomUtils:error("[JobManager] Failed to create FIELDWORK job type.")
            employee.currentJob = nil
        return 
    end

    local field = g_fieldManager:getFieldById(fieldId)
    local farmId = g_currentMission:getFarmId()

    local x, z = field:getCenterOfFieldWorldPosition()
    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local distance = MathUtil.vector2Length(vx - x, vz - z)
    aiJob.isDirectStart = distance < 50

    aiJob:applyCurrentState(vehicle, g_currentMission, farmId, aiJob.isDirectStart)

    if not aiJob.isDirectStart then
        aiJob.positionAngleParameter:setPosition(x, z)
    else
        local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
        local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
        aiJob.positionAngleParameter:setAngle(angle)
    end

    aiJob:setValues()

    local validateSuccess, errorMessage = aiJob:validate(farmId)

    if validateSuccess then
        CustomUtils:info("[JobManager] AI Job validated successfully. Executing startJob...")
        g_currentMission.aiSystem:startJob(aiJob, farmId)

        if vehicle:getIsAIActive() then
            CustomUtils:info("[JobManager] SUCCESS: Vehicle AI is now ACTIVE.")
        else
            CustomUtils:warning("[JobManager] WARNING: startJob called but Vehicle AI is NOT active immediately. This might be async or failed silently.")
        end

        employee.currentJob = {
            aiJobId = aiJob.jobId,
            type = "FIELDWORK",
            fieldId = fieldId,
            workType = workType,
            startTime = g_currentMission.time
        }
        employee.pendingJob = nil
        CustomUtils:info("[JobManager] Employee %s is now autonomously working on field %d (%s)", employee.name, fieldId, workType)
    else
        CustomUtils:error("[JobManager] AI Job validation failed: %s", tostring(errorMessage))
        employee.currentJob = nil
    end
end

---Checks if vehicle has required tool, otherwise rents one
function JobManager:ensureEquipment(vehicle, workType, callback)
    local categoryName = JobManager.WORK_TYPE_TO_CATEGORY[workType]
    if not categoryName then
        callback(true)
        return
    end

    local attachedImplements = vehicle:getAttachedImplements()
    local hasAttachedTool = #attachedImplements > 0

    for _, implement in ipairs(attachedImplements) do
        local obj = implement.object
        if obj ~= nil and obj.getIsAIJobSupported ~= nil and obj:getIsAIJobSupported("AIJobFieldWork") then
            callback(true)
            return
        end
    end

    if hasAttachedTool then
        CustomUtils:warning("[JobManager] Vehicle already has an implement attached but it doesn't support %s. Cannot attach another.", workType)
        callback(false)
        return
    end

    local parkedTool = self:findToolInParking(categoryName, vehicle)
    if parkedTool then
        CustomUtils:info("[JobManager] Found owned tool %s in parking, attaching...", parkedTool:getName())
        if vehicle.attachImplement then
            vehicle:attachImplement(parkedTool, 1, 1)
        end
        callback(true)
        return
    end

    CustomUtils:info("[JobManager] No tool found for %s. Renting equipment...", workType)
    local storeItem = self:findSuitableTool(categoryName)
    if storeItem then
        self:rentAndAttach(vehicle, storeItem, callback)
    else
        CustomUtils:error("[JobManager] No suitable tool found in category %s", categoryName)
        callback(false)
    end
end

function JobManager:findSuitableTool(categoryName)
    local items = g_storeManager:getItems()
    for _, item in pairs(items) do
        if item.categoryName == categoryName then
            return item
        end
    end
    return nil
end

function JobManager:rentAndAttach(vehicle, storeItem, callback)
    local farmId = g_currentMission:getFarmId()

    local rentalFee = storeItem.price * 0.05
    g_currentMission:addMoney(-rentalFee, farmId, MoneyType.SHOP_VEHICLE_BUY, true)

    local function asyncCallback(target, vehicles, vehicleLoadState, arguments)
        if vehicleLoadState == VehicleLoadingState.OK then
            local tool = vehicles[1]

            local vehicleJointIndex = 1
            local toolJointIndex = 1

            if vehicle.getAttacherJoints and tool.getInputAttacherJoints then
                local vJoints = vehicle:getAttacherJoints()
                local tJoints = tool:getInputAttacherJoints()

                local rearIndices = {}
                for i, joint in ipairs(vJoints) do
                    local lx, ly, lz = localToLocal(joint.jointTransform, vehicle.rootNode, 0, 0, 0)
                    if joint.attacherJointDirection == -1 or lz < -0.2 then
                        table.insert(rearIndices, i)
                    end
                end

                local found = false
                for _, vIdx in ipairs(#rearIndices > 0 and rearIndices or {1}) do
                    local vJoint = vJoints[vIdx]
                    for tIdx, tJoint in ipairs(tJoints) do
                        if vJoint.jointType == tJoint.jointType then
                            vehicleJointIndex = vIdx
                            toolJointIndex = tIdx
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
            end

            CustomUtils:debug("[JobManager] Attaching %s (Joint: %d) to %s (Joint: %d)",
                tool:getName(), toolJointIndex, vehicle:getName(), vehicleJointIndex)

            if vehicle.attachImplement then
                vehicle:attachImplement(tool, toolJointIndex, vehicleJointIndex)
            end

            local employee = arguments.employee
            if employee then
                if employee.assignedVehicleId == vehicle.id then
                    employee.temporaryRental = tool.id
                    employee.isRenting = true
                else
                    CustomUtils:error("[JobManager] Unauthorized rental attempt for employee %s", employee.name)
                    callback(false)
                    return
                end
            end

            CustomUtils:info("[JobManager] Successfully rented and attached %s (Rear Joint: %d)", tool:getName(), vehicleJointIndex)
            callback(true)
        else
            callback(false)
        end
    end

    local data = VehicleLoadingData.new()
    local x, y, z = getWorldTranslation(vehicle.rootNode)

    local dx, dy, dz = localDirectionToWorld(vehicle.rootNode, 0, 0, -5)
    data:setStoreItem(storeItem)
    data:setPosition(x + dx, y + 1, z + dz)
    data:setPropertyState(VehiclePropertyState.LEASED)
    data:setOwnerFarmId(farmId)

    local employee = g_employeeManager:getEmployeeByVehicle(vehicle)

    data:load(asyncCallback, self, { employee = employee })
end

---Stops a job for an employee
---@param employee table
---@return boolean Success
function JobManager:stopJob(employee)
    if not employee or not employee.currentJob then
        return false
    end

    local aiJobId = employee.currentJob.aiJobId
    if aiJobId then
        g_currentMission.aiSystem:stopJobById(aiJobId, AIMessageErrorUnknown.new())
    end

    employee.currentJob = nil

    if employee.temporaryRental then
        g_employeeManager:returnRentedEquipment(employee)
    end

    CustomUtils:info("[JobManager] Stopped job for employee %s", employee.name)
    return true
end

function JobManager:handleFieldworkCompletion(employee)
    if employee.temporaryRental then
        g_employeeManager:returnRentedEquipment(employee)
    end

    if g_employeeManager then
        g_employeeManager:onJobCompleted(employee)
    end

    if g_parkingManager and employee.assignedVehicleId then
        local spot = g_parkingManager:getSpotForVehicle(employee.assignedVehicleId)
        if spot then
            local vehicle = g_employeeManager:getVehicleById(employee.assignedVehicleId)
            if vehicle and vehicle.rootNode then
                local vx, _, vz = getWorldTranslation(vehicle.rootNode)
                local dx = vx - spot.x
                local dz = vz - spot.z
                local dist = math.sqrt(dx * dx + dz * dz)

                if dist > 20 then
                    CustomUtils:info("[JobManager] %s returning to parking '%s' (%.0fm away)", employee.name, spot.name, dist)
                    self:startReturnToParking(employee, vehicle, spot)
                    return
                end
            end
        end
    end

    employee.currentJob = nil
end

function JobManager:startReturnToParking(employee, vehicle, spot)
    local aiJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.GOTO)
    if not aiJob then
        CustomUtils:error("[JobManager] Failed to create GOTO job for parking return")
        employee.currentJob = nil
        return
    end

    local farmId = g_currentMission:getFarmId()
    aiJob:applyCurrentState(vehicle, g_currentMission, farmId, false)
    aiJob.positionAngleParameter:setPosition(spot.x, spot.z)
    aiJob.positionAngleParameter:setAngle(spot.angle or 0)
    aiJob:setValues()

    local validateSuccess, errorMessage = aiJob:validate(farmId)
    if validateSuccess then
        g_currentMission.aiSystem:startJob(aiJob, farmId)
        employee.currentJob = {
            aiJobId = aiJob.jobId,
            type = "RETURN_TO_PARKING",
            spotId = spot.id,
            startTime = g_currentMission.time,
        }
        CustomUtils:info("[JobManager] %s is now returning to parking '%s'", employee.name, spot.name)
    else
        CustomUtils:error("[JobManager] Parking return GOTO failed validation: %s", tostring(errorMessage))
        employee.currentJob = nil
    end
end

function JobManager:handleParkingArrival(employee)
    local vehicle = g_employeeManager:getVehicleById(employee.assignedVehicleId)
    if vehicle then
        if vehicle.stopMotor and vehicle:getIsMotorStarted() then
            vehicle:stopMotor()
            CustomUtils:info("[JobManager] %s arrived at parking, motor stopped", employee.name)
        end
    end

    employee.currentJob = nil
    if g_employeeManager then
        g_employeeManager:onJobCompleted(employee)
    end
end

function JobManager:findToolInParking(categoryName, vehicle)
    if not g_parkingManager then return nil end

    local tool, spot = g_parkingManager:findToolInParking(categoryName)
    if tool and spot and vehicle and vehicle.rootNode then
        local vx, _, vz = getWorldTranslation(vehicle.rootNode)
        local dx = vx - spot.x
        local dz = vz - spot.z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist < 50 then
            return tool
        end
    end
    return nil
end

function JobManager:update(dt)
    for _, employee in ipairs(g_employeeManager.employees) do
        if employee.currentJob and employee.currentJob.aiJobId then
            local aiJob = g_currentMission.aiSystem:getJobById(employee.currentJob.aiJobId)

            employee.debugTimer = (employee.debugTimer or 0) + dt
            if employee.debugTimer > 5000 then
                employee.debugTimer = 0
                local vehicle = g_employeeManager:getVehicleById(employee.assignedVehicleId)
                local speed = vehicle and vehicle:getLastSpeed() or 0
                local isAIActive = vehicle and vehicle:getIsAIActive() or false

                if aiJob then
                    CustomUtils:debug("[JobMonitor] %s: Job %d (Type: %s) | AI Active: %s | Speed: %.1f km/h | Status: RUNNING", 
                        employee.name, aiJob.jobId, employee.currentJob.type, tostring(isAIActive), speed)
                else
                    CustomUtils:warning("[JobMonitor] %s: Job %d stored in employee but NOT found in AI System!", employee.name, employee.currentJob.aiJobId)
                end
            end

            if not aiJob then
                CustomUtils:info("[JobManager] Job %d for employee %s finished or removed", employee.currentJob.aiJobId, employee.name)

                if employee.currentJob.type == "TRANSIT" and employee.pendingJob then
                    CustomUtils:info("[JobManager] Transit complete. Starting pending fieldwork...")
                    local vehicle = g_employeeManager:getVehicleById(employee.assignedVehicleId)
                    local pending = employee.pendingJob
                    self:startFieldWorkJob(employee, vehicle, pending.fieldId, pending.workType)
                elseif employee.currentJob.type == "RETURN_TO_PARKING" then
                    self:handleParkingArrival(employee)
                elseif employee.currentJob.type == "FIELDWORK" then
                    self:handleFieldworkCompletion(employee)
                else
                    employee.currentJob = nil
                    if g_employeeManager then
                        g_employeeManager:onJobCompleted(employee)
                    end
                    if employee.temporaryRental then
                        g_employeeManager:returnRentedEquipment(employee)
                    end
                end
            end
        elseif employee.currentJob and employee.currentJob.type == "PREPARING" then
            employee.debugTimer = (employee.debugTimer or 0) + dt
            if employee.debugTimer > 5000 then
                employee.debugTimer = 0
                CustomUtils:debug("[JobMonitor] %s: Job PREPARING (Waiting for equipment/start)...", employee.name)
            end
        end
    end
end
