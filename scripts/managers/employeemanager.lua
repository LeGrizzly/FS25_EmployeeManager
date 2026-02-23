EmployeeManager = {}

local EmployeeManager_mt = Class(EmployeeManager)

---@param mission table
---@return table
function EmployeeManager:new(mission)
    local self = setmetatable({}, EmployeeManager_mt)
    self.mission = mission
    self.employees = {}
    
    -- Initialize Managers
    self.courseManager = CourseManager:new(mission)
    self.cropManager = CropManager:new(mission)
    self.jobManager = JobManager:new(mission)
    
    -- Data Storage
    self.employees = {}
    self.fieldConfigs = {} -- Stores configuration for each field: { cropName="WHEAT", assignments={PLOW=id1, SOW=id2} }
    
    -- Employee generation data
    self.firstNames = {"John", "Peter", "Mike", "David", "Chris", "Paul", "Mark", "James", "Andrew", "Daniel"}
    self.lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"}

    CustomUtils:debug("[EmployeeManager] Initialized")
    return self
end

function EmployeeManager:onMissionInitialize(baseDirectory)
    CustomUtils:info("[EmployeeManager] Mission initialized. Registering console commands...")
    
    -- Register console commands via CommandManager
    if g_commandManager then
        g_commandManager:add('emAssignVehicle', 'Assigns a vehicle to an employee', 'emAssignVehicle <id> <vehId>', 'consoleAssignVehicle', self)
        g_commandManager:add('emUnassignVehicle', 'Unassigns a vehicle from an employee', 'emUnassignVehicle <id>', 'consoleUnassignVehicle', self)
        g_commandManager:add('emDebugVehicles', 'List all vehicles owned by the farm', 'emDebugVehicles', 'consoleDebugVehicles', self)
        g_commandManager:add('emStatus', 'Checks the status of employees and jobs', 'emStatus', 'consoleStatus', self)
        g_commandManager:add('emStartFieldWork', 'Starts a field work job', 'emStartFieldWork <id> <fieldId> <type>', 'consoleStartFieldWork', self)
        g_commandManager:add('emStartJob', 'Starts full autonomy for an employee (Requires target crop)', 'emStartJob <id> [fieldId] [cropName]', 'consoleStartJob', self)
        g_commandManager:add('emStopJob', 'Stops the current job', 'emStopJob <id>', 'consoleStopJob', self)
        g_commandManager:add('emSetTargetCrop', 'Sets a target crop for an employee on a field for full autonomy', 'emSetTargetCrop <id> <fieldId> <cropName>', 'consoleSetTargetCrop', self)
        g_commandManager:add('emListCrops', 'Lists all supported target crops', 'emListCrops', 'consoleListCrops', self)

        -- New management commands
        g_commandManager:add('emHire', 'Hires a candidate by ID', 'emHire <id>', 'consoleHire', self)
        g_commandManager:add('emFire', 'Fires an employee by ID', 'emFire <id>', 'consoleFire', self)
        g_commandManager:add('emListCandidates', 'Lists available candidates for hire', 'emListCandidates', 'consoleListCandidates', self)
        g_commandManager:add('emListFields', 'Lists all fields owned by your farm', 'emListFields', 'consoleListFields', self)
        g_commandManager:add('emRentVehicle', 'Rents a vehicle for an employee by store item name', 'emRentVehicle <empId> <storeItemName>', 'consoleRentVehicle', self)
        g_commandManager:add('emClearAll', 'Clears all employees (DEBUG)', 'emClearAll', 'consoleClearAll', self)
    else
        CustomUtils:error("[EmployeeManager] CommandManager not found!")
    end
end

function EmployeeManager:update(dt)
    if self.jobManager then
        self.jobManager:update(dt)
    end
    if self.courseManager then
        self.courseManager:update(dt)
    end

    -- Financial impact: calculate and deduct wages
    local farmId = g_currentMission:getFarmId()
    local totalWagesToPay = 0
    
    for _, employee in ipairs(self.employees) do
        -- 1. Progress current job and wages
        if employee.isHired and employee.currentJob ~= nil then
            local hoursWorked = employee:updateWorkTime(dt)
            if hoursWorked > 0 then
                local wage = employee:getHourlyWage() * hoursWorked
                totalWagesToPay = totalWagesToPay + wage
                
                -- Progression logic: XP Gain (per hour worked)
                employee:addExperience("driving", hoursWorked * 10)
                if employee.currentJob.type == "FIELDWORK" and employee.currentJob.workType == "HARVEST" then
                    employee:addExperience("harvesting", hoursWorked * 15)
                end
                employee:addExperience("technical", hoursWorked * 5)
            end
        end

        -- 2. Autonomy: If idle but has targetCrop, decide next step
        if employee.isHired and employee.isAutonomous and employee.currentJob == nil and employee.targetCrop ~= nil and employee.targetFieldId ~= nil then
            
            -- Throttle decision making to once every 5 seconds to save performance
            employee.decisionTimer = (employee.decisionTimer or 0) + dt
            if employee.decisionTimer > 5000 then
                employee.decisionTimer = 0
                
                local field = g_fieldManager:getFieldById(employee.targetFieldId)
                if field then
                    local nextStep, reason = self.cropManager:getNextStep(field, employee.targetCrop)
                    if nextStep ~= nil and nextStep ~= "WAIT" then
                        CustomUtils:info("[EmployeeManager] %s deciding next step for %s on field %d: %s (%s)", 
                            employee.name, employee.targetCrop, employee.targetFieldId, nextStep, reason)
                        
                        -- Start the job
                        self.jobManager:startFieldWork(employee, employee.targetFieldId, nextStep)
                    else
                        -- Log why we are waiting
                        CustomUtils:debug("[EmployeeManager] %s is WAITING on field %d (%s): %s", 
                            employee.name, employee.targetFieldId, employee.targetCrop, reason or "No action needed")
                    end
                else
                    CustomUtils:error("[EmployeeManager] Target field %d not found for employee %s", employee.targetFieldId, employee.name)
                    employee.isAutonomous = false -- Abort autonomy
                end
            end
        end
    end

    if totalWagesToPay > 0 then
        -- Deduct money from farm (using MoneyType.WORKER_WAGES if available, or just OTHER)
        local moneyType = MoneyType.WORKER_WAGES or MoneyType.OTHER
        g_currentMission:addMoney(-totalWagesToPay, farmId, moneyType, true)
    end
end
--#region Employee Management

---Returns list of hired employees
---@return table
function EmployeeManager:getHiredEmployees()
    local hired = {}
    for _, e in ipairs(self.employees) do
        if e.isHired then
            table.insert(hired, e)
        end
    end
    return hired
end

---Returns list of available (not hired) employees
---@return table
function EmployeeManager:getAvailableEmployees()
    local available = {}
    for _, e in ipairs(self.employees) do
        if not e.isHired then
            table.insert(available, e)
        end
    end
    return available
end

---Finds an employee by ID
---@param id number
---@return table|nil
function EmployeeManager:getEmployeeById(id)
    for _, e in ipairs(self.employees) do
        if e.id == id then
            return e
        end
    end
    return nil
end

---Finds a hired employee assigned to a specific vehicle
---@param vehicle table
---@return table|nil
function EmployeeManager:getEmployeeByVehicle(vehicle)
    if vehicle == nil then return nil end
    for _, e in ipairs(self.employees) do
        if e.isHired and e.assignedVehicleId == vehicle.id then
            return e
        end
    end
    return nil
end

---Returns rented equipment for an employee
---@param employee table
function EmployeeManager:returnRentedEquipment(employee)
    if not employee or not employee.temporaryRental then return end
    
    local toolId = employee.temporaryRental
    local tool = self:getVehicleById(toolId)
    
    if tool then
        CustomUtils:info("[EmployeeManager] Returning rented equipment %s for employee %s", tool:getName(), employee.name)
        
        -- If attached, detach it first
        local vehicle = self:getVehicleById(employee.assignedVehicleId)
        if vehicle and vehicle.detachImplementByObject then
            vehicle:detachImplementByObject(tool)
        end
        
        -- Delete the rented tool
        tool:delete()
    end
    
    employee.temporaryRental = nil
    employee.isRenting = false
end

---Hires an employee by ID
---@param id number
---@return table|nil The hired employee or nil
function EmployeeManager:hireEmployee(id)
    local employee = self:getEmployeeById(id)
    if employee then
        employee.isHired = true
        g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
        CustomUtils:info("[EmployeeManager] Hired employee %d (%s)", id, employee.name)
        return employee
    end
    CustomUtils:error("[EmployeeManager] Failed to hire employee: ID %d not found", id)
    return nil
end

---Fires an employee by ID
---@param id number
---@return boolean Success
function EmployeeManager:fireEmployee(id)
    local employee = self:getEmployeeById(id)
    if employee then
        -- Stop current job if any
        if employee.currentJob then
            self.jobManager:stopJob(employee)
        end
        
        -- Return rented equipment
        self:returnRentedEquipment(employee)

        employee.isHired = false
        employee:unassignVehicle()
        employee.assignedField = nil
        employee.workTime = 0
        g_messageCenter:publish(MessageType.EMPLOYEE_REMOVED)
        CustomUtils:info("[EmployeeManager] Fired employee %d (%s)", id, employee.name)
        return true
    end
    CustomUtils:error("[EmployeeManager] Failed to fire employee: ID %d not found", id)
    return false
end

---Generates a new random employee and adds to list
---@return table The new employee
function EmployeeManager:generateRandomEmployee()
    math.randomseed(g_currentMission.time + math.random(1, 1000))
    local firstName = self.firstNames[math.random(#self.firstNames)]
    local lastName = self.lastNames[math.random(#self.lastNames)]
    local name = string.format("%s %s", firstName, lastName)
    
    local skills = {
        driving = math.random(1, 5),
        harvesting = math.random(1, 5),
        technical = math.random(1, 5)
    }

    local id = #self.employees + 1
    local emp = Employee.new(id, name, skills)
    emp.isHired = false
    
    table.insert(self.employees, emp)
    CustomUtils:debug("[EmployeeManager] Generated random employee: %s (ID: %d)", name, id)
    return emp
end

--#endregion

--#region Vehicle Management

---Finds a vehicle by its ID in the global vehicle system
---@param vehicleId number
---@return table|nil
function EmployeeManager:getVehicleById(vehicleId)
    if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle.id == vehicleId then
                return vehicle
            end
        end
    end
    return nil
end

---Assigns a vehicle to an employee
---@param employeeId number
---@param vehicleId number
---@return boolean Success
function EmployeeManager:assignVehicleToEmployee(employeeId, vehicleId)
    local employee = self:getEmployeeById(employeeId)
    if not employee then
        CustomUtils:error("[EmployeeManager] Employee ID %d not found", employeeId)
        return false
    end

    local vehicle = self:getVehicleById(vehicleId)
    if not vehicle then
        CustomUtils:error("[EmployeeManager] Vehicle ID %d not found", vehicleId)
        return false
    end

    -- Check if vehicle is already assigned to another employee?
    -- For now, just overwrite
    if employee:assignVehicle(vehicle) then
        CustomUtils:info("[EmployeeManager] Assigned vehicle %s (ID: %d) to employee %s (ID: %d)", vehicle:getName(), vehicleId, employee.name, employeeId)
        return true
    end

    return false
end

---Unassigns vehicle from employee
---@param employeeId number
---@return boolean Success
function EmployeeManager:unassignVehicleFromEmployee(employeeId)
    local employee = self:getEmployeeById(employeeId)
    if not employee then
        CustomUtils:error("[EmployeeManager] Employee ID %d not found", employeeId)
        return false
    end

    employee:unassignVehicle()
    CustomUtils:info("[EmployeeManager] Unassigned vehicle from employee %s (ID: %d)", employee.name, employeeId)
    return true
end

---Detects work type based on attached equipment
---@param employee table
---@return string|nil
function EmployeeManager:detectWorkTypeFromEquipment(employee)
    local vehicle = self:getVehicleById(employee.assignedVehicleId)
    if not vehicle then return nil end
    
    local attachedImplements = vehicle:getAttachedImplements()
    for _, implement in ipairs(attachedImplements) do
        local obj = implement.object
        if obj.spec_plow then return "PLOW" end
        if obj.spec_cultivator then return "CULTIVATE" end
        if obj.spec_sower then return "SOW" end
        if obj.spec_cutter or obj.spec_combine then return "HARVEST" end
        if obj.spec_mower then return "MOW" end
        if obj.spec_sprayer then return "FERTILIZE" end
        if obj.spec_stonePicker then return "STONES" end
        if obj.spec_roller then return "ROLL" end
        if obj.spec_weeder then return "WEED" end
        if obj.spec_mulcher then return "MULCH" end
        if obj.spec_tedder then return "TEDDER" end
        if obj.spec_windrower then return "WINDROWER" end
    end
    
    return nil
end

--#endregion

--#region Console Commands

function EmployeeManager:consoleHire(id)
    id = tonumber(id)
    if not id then return "Usage: emHire <id>" end
    
    local employee = self:getEmployeeById(id)
    if not employee then return string.format("Employee %d not found", id) end
    if employee.isHired then return string.format("Employee %d is already hired", id) end
    
    if self:hireEmployee(id) then
        return string.format("Hired %s (%d)", employee.name, id)
    else
        return string.format("Failed to hire employee %d", id)
    end
end

function EmployeeManager:consoleFire(id)
    id = tonumber(id)
    if not id then return "Usage: emFire <id>" end
    
    local employee = self:getEmployeeById(id)
    if not employee then return string.format("Employee %d not found", id) end
    if not employee.isHired then return string.format("Employee %d is not hired", id) end
    
    if self:fireEmployee(id) then
        return string.format("Fired %s (%d)", employee.name, id)
    else
        return string.format("Failed to fire employee %d", id)
    end
end

function EmployeeManager:consoleListCandidates()
    print("--- Available Candidates ---")
    local candidates = self:getAvailableEmployees()
    for _, e in ipairs(candidates) do
        print(string.format("  [%d] %s", e.id, e.name))
        print(string.format("     DRV: %d | HAR: %d | TEC: %d", e.skills.driving, e.skills.harvesting, e.skills.technical))
    end
    return string.format("Found %d candidates.", #candidates)
end

function EmployeeManager:consoleListFields()
    print("--- Owned Fields ---")
    local farmId = g_currentMission:getFarmId()
    local fields = g_fieldManager.fields
    local count = 0
    if fields then
        for _, field in pairs(fields) do
            local farmlandId = field.farmlandId
            if farmlandId == nil and field.getFarmland then
                local farmland = field:getFarmland()
                if farmland then farmlandId = farmland.id end
            end

            if farmlandId ~= nil then
                local ownerId = g_farmlandManager:getFarmlandOwner(farmlandId)
                if ownerId == farmId then
                    print(string.format("  Field ID: %d (Farmland: %d)", field:getId(), farmlandId))
                    count = count + 1
                end
            end
        end
    end
    return string.format("Found %d fields for your farm.", count)
end

---Rents a vehicle for an employee
---@param employee table
---@param storeItem table
function EmployeeManager:rentVehicle(employee, storeItem)
    local farmId = g_currentMission:getFarmId()
    
    -- Rental cost (simplified: 5% of price for initial hire)
    local rentalFee = storeItem.price * 0.05
    g_currentMission:addMoney(-rentalFee, farmId, MoneyType.SHOP_VEHICLE_BUY, true)

    local function asyncCallback(target, vehicles, vehicleLoadState, arguments)
        if vehicleLoadState == VehicleLoadingState.OK then
            local vehicle = vehicles[1]
            employee:assignVehicle(vehicle)
            employee.isRenting = true
            CustomUtils:info("[EmployeeManager] Successfully rented %s for %s", vehicle:getName(), employee.name)
        else
            CustomUtils:error("[EmployeeManager] Failed to load rented vehicle for %s", employee.name)
        end
    end

    local data = VehicleLoadingData.new()
    local x, y, z = getWorldTranslation(g_currentMission.player.rootNode)
    data:setStoreItem(storeItem)
    data:setPosition(x + 5, y, z + 5)
    data:setPropertyState(VehiclePropertyState.LEASED)
    data:setOwnerFarmId(farmId)
    
    data:load(asyncCallback, self)
end

function EmployeeManager:consoleRentVehicle(employeeId, storeItemName)
    employeeId = tonumber(employeeId)
    if not employeeId or not storeItemName then
        return "Usage: emRentVehicle <empId> <storeItemName>"
    end

    local employee = self:getEmployeeById(employeeId)
    if not employee then return string.format("Employee %d not found", employeeId) end
    if not employee.isHired then return "Employee must be hired first" end

    local storeItem = g_storeManager:getItemByName(storeItemName)
    if not storeItem then
        return string.format("Store item '%s' not found", storeItemName)
    end

    self:rentVehicle(employee, storeItem)
    return string.format("Ordering rental of %s for employee %s...", storeItemName, employee.name)
end

function EmployeeManager:consoleAssignVehicle(employeeId, vehicleId)
    employeeId = tonumber(employeeId)
    vehicleId = tonumber(vehicleId)

    if not employeeId or not vehicleId then
        return "Usage: emAssignVehicle <employeeId> <vehicleId>"
    end

    if self:assignVehicleToEmployee(employeeId, vehicleId) then
        return string.format("Successfully assigned vehicle %d to employee %d", vehicleId, employeeId)
    else
        return string.format("Failed to assign vehicle %d to employee %d (Check logs for details)", vehicleId, employeeId)
    end
end

function EmployeeManager:consoleUnassignVehicle(employeeId)
    employeeId = tonumber(employeeId)

    if not employeeId then
        return "Usage: emUnassignVehicle <employeeId>"
    end

    if self:unassignVehicleFromEmployee(employeeId) then
        return string.format("Successfully unassigned vehicle from employee %d", employeeId)
    else
        return string.format("Failed to unassign vehicle from employee %d", employeeId)
    end
end

function EmployeeManager:consoleClearAll()
    self.employees = {}
    for i = 1, 10 do
        self:generateRandomEmployee()
    end
    return "All employees cleared and pool regenerated."
end

function EmployeeManager:consoleSetTargetCrop(id, fieldId, cropName)
    id = tonumber(id)
    fieldId = tonumber(fieldId)
    cropName = tostring(cropName):upper()

    if not id or not fieldId or not cropName then
        return "Usage: emSetTargetCrop <id> <fieldId> <cropName>"
    end

    local employee = self:getEmployeeById(id)
    if not employee then return "Employee not found" end
    
    if not self.cropManager.crops[cropName] then
        return "Unknown crop name. Use 'emListCrops' to see supported crops."
    end

    employee.targetFieldId = fieldId
    employee.targetCrop = cropName
    
    return string.format("Employee %s will now autonomously manage field %d for crop %s", employee.name, fieldId, cropName)
end

function EmployeeManager:consoleListCrops()
    print("--- Supported Target Crops ---")
    for name, data in pairs(self.cropManager.crops) do
        print(string.format("  - %s (%s)", name, data.category))
    end
    return "End of crop list."
end

function EmployeeManager:consoleStartFieldWork(employeeId, fieldId, workType)
    employeeId = tonumber(employeeId)
    fieldId = tonumber(fieldId)

    if not employeeId or not fieldId then
        return "Usage: emStartFieldWork <employeeId> <fieldId> [workType]"
    end

    local employee = self:getEmployeeById(employeeId)
    if not employee then
        return string.format("Employee %d not found", employeeId)
    end

    local field = g_fieldManager:getFieldById(fieldId)
    if not field then
        return string.format("Field %d not found", fieldId)
    end

    -- Automatic detection if workType is not specified or UNKNOWN
    local detectionReason = "No specific reason"
    if workType == nil or workType == "UNKNOWN" then
        -- 1. Try with targetCrop (Autonomy logic)
        if employee.targetCrop then
            local nextStep, reason = self.cropManager:getNextStep(field, employee.targetCrop)
            detectionReason = reason or "Unknown reason"
            if nextStep and nextStep ~= "WAIT" then
                workType = nextStep
                CustomUtils:info("[EmployeeManager] Auto-detected workType %s for %s (Crop: %s, Reason: %s)", workType, employee.name, employee.targetCrop, reason)
            end
        end

        -- 2. If still unknown, try with attached equipment
        if workType == nil or workType == "UNKNOWN" then
            workType = self:detectWorkTypeFromEquipment(employee)
            if workType then
                CustomUtils:info("[EmployeeManager] Auto-detected workType %s for %s based on equipment", workType, employee.name)
            else
                detectionReason = detectionReason .. " | No suitable tool attached"
            end
        end
    end

    -- If STILL unknown, we can't start
    if workType == nil or workType == "UNKNOWN" then
        return string.format("Could not determine workType for employee %d on field %d. Reason: %s. Please specify it or set a target crop/attach a tool.", employeeId, fieldId, detectionReason)
    end

    if self.jobManager:startFieldWork(employee, fieldId, workType) then
        return string.format("Started %s on field %d for employee %s (%d)", workType, fieldId, employee.name, employeeId)
    else
        return string.format("Failed to start job for employee %d (Check logs for details)", employeeId)
    end
end

function EmployeeManager:consoleStartJob(employeeId, fieldId, actionOrCrop)
    employeeId = tonumber(employeeId)
    fieldId = tonumber(fieldId)
    
    local employee = self:getEmployeeById(employeeId)
    if not employee then
        return string.format("Employee %d not found", employeeId)
    end

    if not fieldId then
        return "Usage: emStartJob <id> <fieldId> [cropName OR action]"
    end

    -- Check if actionOrCrop is a specific WorkType (Forced Action)
    local workType = tostring(actionOrCrop):upper()
    if self.jobManager.WORK_TYPE_TO_CATEGORY[workType] then
        -- It's a forced action!
        if self.jobManager:startFieldWork(employee, fieldId, workType) then
            return string.format("FORCED ACTION STARTED: Employee %s will %s field %d immediately.", employee.name, workType, fieldId)
        else
             return string.format("Failed to force start %s for employee %d (Check logs)", workType, employeeId)
        end
    end

    -- Otherwise, treat it as a Crop Name for full autonomy
    if actionOrCrop then
        local res = self:consoleSetTargetCrop(employeeId, fieldId, actionOrCrop)
        CustomUtils:info(res)
    end
    
    if not employee.targetFieldId or not employee.targetCrop then
        return "Employee needs a target field and crop before starting autonomous work. Usage: emStartJob <id> [fieldId] [cropName]"
    end
    
    employee.isAutonomous = true
    return string.format("Full autonomy STARTED for employee %s on field %d for crop %s", employee.name, employee.targetFieldId, employee.targetCrop)
end

function EmployeeManager:consoleStopJob(employeeId)
    employeeId = tonumber(employeeId)

    if not employeeId then
        return "Usage: emStopJob <employeeId>"
    end

    local employee = self:getEmployeeById(employeeId)
    if not employee then
        return string.format("Employee %d not found", employeeId)
    end

    employee.isAutonomous = false
    
    if self.jobManager:stopJob(employee) then
        return string.format("Stopped job and autonomy for employee %s (%d)", employee.name, employeeId)
    else
        return string.format("Stopped autonomy for employee %s (%d) (No active job found)", employee.name, employeeId)
    end
end

function EmployeeManager:consoleDebugVehicles()
    local count = 0
    print("--- Farm Vehicles List ---")
    if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles then
        local currentFarmId = g_currentMission:getFarmId()
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle.ownerFarmId == currentFarmId then
                print(string.format("ID: %d | Name: %s | Type: %s", vehicle.id, vehicle:getName(), vehicle.typeName or "Unknown"))
                count = count + 1
            end
        end
    end
    return string.format("Found %d vehicles for current farm.", count)
end

function EmployeeManager:consoleStatus()
    local hiredCount = #self:getHiredEmployees()
    local totalCount = #self.employees
    local msg = string.format("EmployeeManager Status:\n- Total Employees: %d\n- Hired: %d\n- Available: %d", 
        totalCount, hiredCount, totalCount - hiredCount)
    
    print(msg)
    
    -- Print details of hired employees
    if hiredCount > 0 then
        print("Hired Employees:")
        for _, e in ipairs(self:getHiredEmployees()) do
            local vehicleInfo = "None"
            if e.assignedVehicleId then
                local v = self:getVehicleById(e.assignedVehicleId)
                if v then
                    vehicleInfo = string.format("%s (ID: %d)", v:getName(), e.assignedVehicleId)
                else
                    vehicleInfo = string.format("Unknown (ID: %d)", e.assignedVehicleId)
                end
            end
            print(string.format("  - [%d] %s | Vehicle: %s", e.id, e.name, vehicleInfo))
            print(string.format("    Skills: DRV %d (%d/%d) | HAR %d (%d/%d) | TEC %d (%d/%d)", 
                e.skills.driving, e.skillXP.driving or 0, e.skills.driving * 100,
                e.skills.harvesting, e.skillXP.harvesting or 0, e.skills.harvesting * 100,
                e.skills.technical, e.skillXP.technical or 0, e.skills.technical * 100))
        end
    end
    
    return "Status check complete."
end

--#endregion

--#region Persistence

function EmployeeManager:saveToXMLFile(xmlFile, key)
    CustomUtils:debug("[EmployeeManager] Saving employees to XML...")
    local empKey = key .. ".employees"
    
    for i, e in ipairs(self.employees) do
        local base = string.format("%s.employee(%d)", empKey, i-1)
        setXMLInt(xmlFile, base .. "#id", e.id)
        setXMLString(xmlFile, base .. "#name", e.name)
        setXMLBool(xmlFile, base .. "#isHired", e.isHired)
        setXMLFloat(xmlFile, base .. "#workTime", e.workTime)
        setXMLFloat(xmlFile, base .. "#kmDriven", e.kmDriven)

        setXMLInt(xmlFile, base .. ".skills#driving", e.skills.driving)
        setXMLInt(xmlFile, base .. ".skills#harvesting", e.skills.harvesting)
        setXMLInt(xmlFile, base .. ".skills#technical", e.skills.technical)
        
        setXMLFloat(xmlFile, base .. ".skills#drivingXP", e.skillXP.driving or 0)
        setXMLFloat(xmlFile, base .. ".skills#harvestingXP", e.skillXP.harvesting or 0)
        setXMLFloat(xmlFile, base .. ".skills#technicalXP", e.skillXP.technical or 0)
        
        if e.assignedVehicleId then
            setXMLInt(xmlFile, base .. "#assignedVehicleId", e.assignedVehicleId)
        end

        if e.currentJob ~= nil then
            setXMLString(xmlFile, base .. ".currentJob#jobType", tostring(e.currentJob.type))
            if e.currentJob.fieldId then
                setXMLInt(xmlFile, base .. ".currentJob#fieldId", e.currentJob.fieldId)
            end
        end

        if e.targetCrop ~= nil then
            setXMLString(xmlFile, base .. "#targetCrop", e.targetCrop)
            setXMLInt(xmlFile, base .. "#targetFieldId", e.targetFieldId or 0)
            setXMLBool(xmlFile, base .. "#isAutonomous", e.isAutonomous or false)
        end
    end
    return true
end

function EmployeeManager:loadFromXMLFile(xmlFile, key)
    CustomUtils:debug("[EmployeeManager] Loading employees from XML...")
    self.employees = {}

    local empKey = key .. ".employees"
    local i = 0
    while true do
        local base = string.format("%s.employee(%d)", empKey, i)
        local id = getXMLInt(xmlFile, base .. "#id")
        if id == nil then
            break
        end
        
        local name = getXMLString(xmlFile, base .. "#name") or ("Employee_" .. tostring(id))
        local driving = Utils.getNoNil(getXMLInt(xmlFile, base .. ".skills#driving"), 1)
        local harvesting = Utils.getNoNil(getXMLInt(xmlFile, base .. ".skills#harvesting"), 1)
        local technical = Utils.getNoNil(getXMLInt(xmlFile, base .. ".skills#technical"), 1)
        
        local emp = Employee.new(id, name, { driving = driving, harvesting = harvesting, technical = technical })
        emp.skillXP.driving = Utils.getNoNil(getXMLFloat(xmlFile, base .. ".skills#drivingXP"), 0)
        emp.skillXP.harvesting = Utils.getNoNil(getXMLFloat(xmlFile, base .. ".skills#harvestingXP"), 0)
        emp.skillXP.technical = Utils.getNoNil(getXMLFloat(xmlFile, base .. ".skills#technicalXP"), 0)
        
        emp.isHired = Utils.getNoNil(getXMLBool(xmlFile, base .. "#isHired"), false)
        emp.workTime = Utils.getNoNil(getXMLFloat(xmlFile, base .. "#workTime"), 0)
        emp.kmDriven = Utils.getNoNil(getXMLFloat(xmlFile, base .. "#kmDriven"), 0)

        local assignedVehicleId = getXMLInt(xmlFile, base .. "#assignedVehicleId")
        if assignedVehicleId then
            local vehicle = self:getVehicleById(assignedVehicleId)
            if vehicle then
                emp:assignVehicle(vehicle)
            else
                -- Store ID anyway if vehicle not loaded yet (though unlikely in runtime load)
                emp.assignedVehicleId = assignedVehicleId 
            end
        end

        local jobType = getXMLString(xmlFile, base .. ".currentJob#jobType")
        local fieldId = getXMLInt(xmlFile, base .. ".currentJob#fieldId")
        if jobType ~= nil then
            emp.currentJob = { type = jobType }
            if fieldId ~= nil then emp.currentJob.fieldId = fieldId end
        end

        emp.targetCrop = getXMLString(xmlFile, base .. "#targetCrop")
        emp.targetFieldId = getXMLInt(xmlFile, base .. "#targetFieldId")
        if emp.targetFieldId == 0 then emp.targetFieldId = nil end
        emp.isAutonomous = Utils.getNoNil(getXMLBool(xmlFile, base .. "#isAutonomous"), false)
        
        table.insert(self.employees, emp)
        i = i + 1
    end
    
    -- Generate available employees pool if needed
    local numToGenerate = 10 - #self.employees
    if numToGenerate > 0 then
        for j = 1, numToGenerate do
            self:generateRandomEmployee()
        end
    end
end

function EmployeeManager:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.employees)
    for _, employee in ipairs(self.employees) do
        employee:writeStream(streamId, connection)
    end
end

function EmployeeManager:readStream(streamId, connection)
    local numEmployees = streamReadInt32(streamId)
    self.employees = {}
    for _ = 1, numEmployees do
        local employee = Employee.new(0, "", {})
        employee:readStream(streamId, connection)
        
        if employee.assignedVehicleId then
            local vehicle = self:getVehicleById(employee.assignedVehicleId)
            if vehicle then
                employee:assignVehicle(vehicle)
            end
        end
        
        table.insert(self.employees, employee)
    end
end

--#endregion
