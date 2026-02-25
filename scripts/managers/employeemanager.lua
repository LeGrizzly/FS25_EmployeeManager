EmployeeManager = {}

local EmployeeManager_mt = Class(EmployeeManager)

---@param mission table
---@return table
function EmployeeManager:new(mission)
    local self = setmetatable({}, EmployeeManager_mt)
    self.mission = mission
    self.employees = {}
    
    self.courseManager = CourseManager:new(mission)
    self.cropManager = CropManager:new(mission)
    self.jobManager = JobManager:new(mission)

    self.employees = {}
    self.fieldConfigs = {}

    self.firstNames = {"John", "Peter", "Mike", "David", "Chris", "Paul", "Mark", "James", "Andrew", "Daniel"}
    self.lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"}

    CustomUtils:debug("[EmployeeManager] Initialized")
    return self
end

function EmployeeManager:onMissionInitialize(baseDirectory)
    CustomUtils:info("[EmployeeManager] Mission initialized. Registering console commands...")

    if g_commandManager then
        g_commandManager:add('emAssignVehicle', 'Assigns a vehicle to an employee', 'emAssignVehicle <id> <vehId>', 'consoleAssignVehicle', self)
        g_commandManager:add('emUnassignVehicle', 'Unassigns a vehicle from an employee', 'emUnassignVehicle <id>', 'consoleUnassignVehicle', self)
        g_commandManager:add('emDebugVehicles', 'List all vehicles owned by the farm', 'emDebugVehicles', 'consoleDebugVehicles', self)
        g_commandManager:add('emHireRandom', 'Hires a random employee', 'emHireRandom', 'generateRandomEmployee', self)
        g_commandManager:add('emList', 'Lists all employees', 'emList', 'consoleListEmployees', self)
        g_commandManager:add('emStartTask', 'Starts a task for an employee', 'emStartTask <id> <taskName> [fieldId]', 'consoleStartTask', self)
        g_commandManager:add('emSetCrop', 'Sets target crop/field for an employee', 'emSetCrop <id> <fieldId> <cropName>', 'consoleSetTargetCrop', self)

        g_commandManager:add('emStatus', 'Checks the status of employees and jobs', 'emStatus', 'consoleStatus', self)
        g_commandManager:add('emStartFieldWork', 'Starts a field work job', 'emStartFieldWork <id> <fieldId> <type>', 'consoleStartFieldWork', self)
        g_commandManager:add('emStartJob', 'Starts full autonomy for an employee (Requires target crop)', 'emStartJob <id> [fieldId] [cropName]', 'consoleStartJob', self)
        g_commandManager:add('emStopJob', 'Stops the current job', 'emStopJob <id>', 'consoleStopJob', self)
        g_commandManager:add('emSetTargetCrop', 'Sets a target crop for an employee on a field for full autonomy', 'emSetTargetCrop <id> <fieldId> <cropName>', 'consoleSetTargetCrop', self)
        g_commandManager:add('emListCrops', 'Lists all supported target crops', 'emListCrops', 'consoleListCrops', self)

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

    local farmId = g_currentMission:getFarmId()
    local totalWagesToPay = 0
    
    for _, employee in ipairs(self.employees) do
        if employee.isHired and employee.currentJob ~= nil then
            local hoursWorked = employee:updateWorkTime(dt)
            if hoursWorked > 0 then
                local wage = employee:getHourlyWage() * hoursWorked
                totalWagesToPay = totalWagesToPay + wage
                
                employee:addExperience("driving", hoursWorked * 10)
                if employee.currentJob.type == "FIELDWORK" and employee.currentJob.workType == "HARVEST" then
                    employee:addExperience("harvesting", hoursWorked * 15)
                end
                employee:addExperience("technical", hoursWorked * 5)
            end
        end

        if employee.isHired and employee.isAutonomous and employee.currentJob == nil and employee.targetCrop ~= nil and employee.targetFieldId ~= nil then
            
            employee.decisionTimer = (employee.decisionTimer or 0) + dt
            if employee.decisionTimer > 5000 then
                employee.decisionTimer = 0
                
                local field = g_fieldManager:getFieldById(employee.targetFieldId)
                if field then
                    local nextStep, reason = self.cropManager:getNextStep(field, employee.targetCrop)
                    if nextStep ~= nil and nextStep ~= "WAIT" then
                        CustomUtils:info("[EmployeeManager] %s deciding next step for %s on field %d: %s (%s)", 
                            employee.name, employee.targetCrop, employee.targetFieldId, nextStep, reason)
                        
                        self.jobManager:startFieldWork(employee, employee.targetFieldId, nextStep)
                    else
                        CustomUtils:debug("[EmployeeManager] %s is WAITING on field %d (%s): %s", 
                            employee.name, employee.targetFieldId, employee.targetCrop, reason or "No action needed")
                    end
                else
                    CustomUtils:error("[EmployeeManager] Target field %d not found for employee %s", employee.targetFieldId, employee.name)
                    employee.isAutonomous = false
                end
            end
        end
    end

    if totalWagesToPay > 0 then
        local moneyType = MoneyType.WORKER_WAGES or MoneyType.OTHER
        g_currentMission:addMoney(-totalWagesToPay, farmId, moneyType, true)
    end
end

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
        
        local vehicle = self:getVehicleById(employee.assignedVehicleId)
        if vehicle and vehicle.detachImplementByObject then
            vehicle:detachImplementByObject(tool)
        end
        
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
        if employee.currentJob then
            self.jobManager:stopJob(employee)
        end

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
    local id = #self.employees + 1
    local firstName = self.firstNames[math.random(#self.firstNames)]
    local lastName = self.lastNames[math.random(#self.lastNames)]
    local name = string.format("%s %s", firstName, lastName)

    local skills = {
        driving = math.random(1, 5),
        harvesting = math.random(1, 5),
        technical = math.random(1, 5)
    }
    
    local employee = Employee.new(id, name, skills)
    table.insert(self.employees, employee)
    CustomUtils:info("[EmployeeManager] Generated new employee: %s (ID: %d)", name, id)
    
    g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
    return employee
end

function EmployeeManager:hireEmployee(id)
    local employee = self:getEmployeeById(id)
    if employee then
        employee.isHired = true
        CustomUtils:info("[EmployeeManager] Hired employee: %s", employee.name)
        g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
    end
end

function EmployeeManager:fireEmployee(id)
    local employee = self:getEmployeeById(id)
    if employee then
        employee.isHired = false
        employee:unassignVehicle()
        employee.currentJob = nil
        CustomUtils:info("[EmployeeManager] Fired employee: %s", employee.name)
        g_messageCenter:publish(MessageType.EMPLOYEE_REMOVED)
    end
end

function EmployeeManager:getEmployeeById(id)
    for _, employee in ipairs(self.employees) do
        if employee.id == id then
            return employee
        end
    end
    return nil
end

function EmployeeManager:getHiredEmployees()
    local hired = {}
    for _, employee in ipairs(self.employees) do
        if employee.isHired then
            table.insert(hired, employee)
        end
    end
    return hired
end

function EmployeeManager:getAvailableEmployees()
    local available = {}
    for _, employee in ipairs(self.employees) do
        if not employee.isHired then
            table.insert(available, employee)
        end
    end
    return available
end

--#endregion

--#region Field Configurations & Workflow

function EmployeeManager:setFieldConfig(fieldId, cropName, assignments)
    self.fieldConfigs[fieldId] = {
        cropName = cropName,
        assignments = assignments or {}
    }
    CustomUtils:info("[EmployeeManager] Configured workflow for Field %d: %s", fieldId, cropName)
end

function EmployeeManager:getAssignedEmployeeForStep(fieldId, stepName)
    local config = self.fieldConfigs[fieldId]
    if config and config.assignments then
        local empId = config.assignments[stepName]
        if empId then
            return self:getEmployeeById(empId)
        end
    end
    return nil
end

--#endregion

--#region Vehicle Management

function EmployeeManager:assignVehicleToEmployee(employeeId, vehicleId)
    local employee = self:getEmployeeById(employeeId)
    local vehicle = self:getVehicleById(vehicleId)
    
    if employee and vehicle then
        employee:assignVehicle(vehicle)
        CustomUtils:info("[EmployeeManager] Assigned vehicle %s to employee %s", vehicle:getName(), employee.name)
        return true
    end
    return false
end

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

--#endregion

--#region Console Commands

function EmployeeManager:consoleAssignVehicle(id, vehId)
    id = tonumber(id)
    vehId = tonumber(vehId)
    if self:assignVehicleToEmployee(id, vehId) then
        return "Vehicle assigned successfully"
    end
    return "Failed to assign vehicle (invalid ID or vehicle not found)"
end

function EmployeeManager:consoleUnassignVehicle(id)
    id = tonumber(id)
    local emp = self:getEmployeeById(id)
    if emp then
        emp:unassignVehicle()
        return "Vehicle unassigned"
    end
    return "Employee not found"
end

function EmployeeManager:consoleListEmployees()
    print("--- Employee List ---")
    for _, e in ipairs(self.employees) do
        local status = e.isHired and "HIRED" or "AVAILABLE"
        local job = e.currentJob and e.currentJob.type or "IDLE"
        print(string.format("[%d] %s | %s | Job: %s", e.id, e.name, status, job))
    end
    return "End of list"
end

function EmployeeManager:consoleStartTask(id, taskName, fieldId)
    id = tonumber(id)
    fieldId = tonumber(fieldId)
    local emp = self:getEmployeeById(id)
    if not emp then return "Employee not found" end
    
    if self.jobManager:startFieldWork(emp, fieldId, taskName) then
        return string.format("Task %s started for %s on Field %d", taskName, emp.name, fieldId)
    end
    return "Failed to start task"
end

function EmployeeManager:consoleSetTargetCrop(id, fieldId, cropName)
    id = tonumber(id)
    fieldId = tonumber(fieldId)
    local emp = self:getEmployeeById(id)
    if emp then
        emp.targetFieldId = fieldId
        emp.targetCrop = cropName
        return "Target crop set"
    end
    return "Employee not found"
end

function EmployeeManager:consoleDebugVehicles()
    local farmId = g_currentMission:getFarmId()
    print("--- Farm Vehicles ---")
    for _, v in pairs(g_currentMission.vehicleSystem.vehicles) do
        if v.ownerFarmId == farmId then
            print(string.format("ID: %d | %s", v.id, v:getName()))
        end
    end
    return "End of list"
end

--#endregion

--#region Save/Load & Sync

function EmployeeManager:saveToXMLFile(xmlFile, key)
    CustomUtils:debug("[EmployeeManager] Saving employees to XML...")
    local empKey = key .. ".employees"
    for i, e in ipairs(self.employees) do
        local base = string.format("%s.employee(%d)", empKey, i - 1)
        setXMLInt(xmlFile, base .. "#id", e.id)
        setXMLString(xmlFile, base .. "#name", e.name)
        setXMLBool(xmlFile, base .. "#isHired", e.isHired)
        setXMLFloat(xmlFile, base .. "#workTime", e.workTime)
        setXMLFloat(xmlFile, base .. "#kmDriven", e.kmDriven)
        setXMLInt(xmlFile, base .. "#assignedVehicleId", e.assignedVehicleId or 0)

        setXMLInt(xmlFile, base .. ".skills#driving", e.skills.driving)
        setXMLInt(xmlFile, base .. ".skills#harvesting", e.skills.harvesting)
        setXMLInt(xmlFile, base .. ".skills#technical", e.skills.technical)
        setXMLFloat(xmlFile, base .. ".skills#drivingXP", e.skillXP.driving)
        setXMLFloat(xmlFile, base .. ".skills#harvestingXP", e.skillXP.harvesting)
        setXMLFloat(xmlFile, base .. ".skills#technicalXP", e.skillXP.technical)

        if e.currentJob ~= nil then
            setXMLString(xmlFile, base .. ".currentJob#jobType", e.currentJob.type)
            setXMLInt(xmlFile, base .. ".currentJob#fieldId", e.currentJob.fieldId or 0)
        end

        if e.targetCrop ~= nil then
            setXMLString(xmlFile, base .. "#targetCrop", e.targetCrop)
            setXMLInt(xmlFile, base .. "#targetFieldId", e.targetFieldId or 0)
            setXMLBool(xmlFile, base .. "#isAutonomous", e.isAutonomous or false)
        end

        setXMLInt(xmlFile, base .. "#shiftStart", e.shiftStart or 6)
        setXMLInt(xmlFile, base .. "#shiftEnd", e.shiftEnd or 18)

        local queue = e.taskQueue or {}
        for qi, taskName in ipairs(queue) do
            local taskKey = string.format("%s.taskQueue.task(%d)", base, qi - 1)
            setXMLString(xmlFile, taskKey .. "#name", taskName)
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
        if assignedVehicleId and assignedVehicleId ~= 0 then
            local vehicle = self:getVehicleById(assignedVehicleId)
            if vehicle then
                emp:assignVehicle(vehicle)
            else
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
        emp.shiftStart = Utils.getNoNil(getXMLInt(xmlFile, base .. "#shiftStart"), 6)
        emp.shiftEnd = Utils.getNoNil(getXMLInt(xmlFile, base .. "#shiftEnd"), 18)

        emp.taskQueue = {}
        local qi = 0
        while true do
            local taskKey = string.format("%s.taskQueue.task(%d)", base, qi)
            local taskName = getXMLString(xmlFile, taskKey .. "#name")
            if taskName == nil then break end
            table.insert(emp.taskQueue, taskName)
            qi = qi + 1
        end

        table.insert(self.employees, emp)
        i = i + 1
    end

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
