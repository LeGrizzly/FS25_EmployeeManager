EmployeeManager = {}

local EmployeeManager_mt = Class(EmployeeManager)

function EmployeeManager:new(mission)
    CustomUtils:debug("[EmployeeManager] new()")
    local self = setmetatable({}, EmployeeManager_mt)
    self.mission = mission
    self.employees = {}
    self.firstNames = {"John", "Peter", "Mike", "David", "Chris", "Paul", "Mark", "James", "Andrew", "Daniel"}
    self.lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"}
    return self
end

function EmployeeManager:onMissionInitialize(baseDirectory)
    CustomUtils:debug("--- Mission Initializing! ---")
    CustomUtils:debug("[FS25_EmployeeManager] EmployeeManager: Mission initialized with base directory: " .. tostring(baseDirectory))
end

function EmployeeManager:getHiredEmployees()
    CustomUtils:debug("[EmployeeManager] getHiredEmployees()")
    local hired = {}
    for _, e in ipairs(self.employees) do
        if e.isHired then
            table.insert(hired, e)
        end
    end
    return hired
end

function EmployeeManager:getAvailableEmployees()
    CustomUtils:debug("[EmployeeManager] getAvailableEmployees()")
    local available = {}
    for _, e in ipairs(self.employees) do
        if not e.isHired then
            table.insert(available, e)
        end
    end
    return available
end

function EmployeeManager:hireEmployee(id)
    CustomUtils:debug("[EmployeeManager] hireEmployee(id: %s)", tostring(id))
    for _, e in ipairs(self.employees) do
        if e.id == id then
            e.isHired = true
            g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
            return e
        end
    end
    return nil
end

function EmployeeManager:fireEmployee(id)
    CustomUtils:debug("[EmployeeManager] fireEmployee(id: %s)", tostring(id))
    for _, e in ipairs(self.employees) do
        if e.id == id then
            e.isHired = false
            -- Reset other properties if needed
            e.assignedVehicle = nil
            e.assignedField = nil
            e.workTime = 0
            g_messageCenter:publish(MessageType.EMPLOYEE_REMOVED)
            return true
        end
    end
    return false
end

function EmployeeManager:generateRandomEmployee()
    CustomUtils:debug("[EmployeeManager] generateRandomEmployee()")
    math.randomseed(g_currentMission.time + math.random(1, 1000))
    local firstName = self.firstNames[math.random(#self.firstNames)]
    local lastName = self.lastNames[math.random(#self.lastNames)]
    local name = firstName .. " " .. lastName
    local skills = {
        driving = math.random(1, 5),
        harvesting = math.random(1, 5),
        technical = math.random(1, 5)
    }

    local id = #self.employees + 1
    local emp = Employee.new(id, name, skills)
    emp.isHired = false
    table.insert(self.employees, emp)
    return emp
end

function EmployeeManager:getEmployeeById(id)
    for _, e in ipairs(self.employees) do
        if e.id == id then
            return e
        end
    end
    return nil
end

function EmployeeManager:saveToXMLFile(xmlFile, key)
    CustomUtils:debug("[EmployeeManager] saveToXMLFile()")
    local hiredEmployees = self:getHiredEmployees()
    local empKey = key .. ".employees"
    for i, e in ipairs(hiredEmployees) do
        local base = string.format("%s.employee(%d)", empKey, i-1)
        setXMLInt(xmlFile, base .. "#id", e.id)
        setXMLString(xmlFile, base .. "#name", e.name)
        setXMLBool(xmlFile, base .. "#isHired", e.isHired)
        setXMLFloat(xmlFile, base .. "#workTime", e.workTime)
        setXMLFloat(xmlFile, base .. "#kmDriven", e.kmDriven)

        setXMLInt(xmlFile, base .. ".skills#driving", e.skills.driving)
        setXMLInt(xmlFile, base .. ".skills#harvesting", e.skills.harvesting)
        setXMLInt(xmlFile, base .. ".skills#technical", e.skills.technical)
        if e.currentJob ~= nil then
            setXMLString(xmlFile, base .. ".currentJob#jobType", tostring(e.currentJob.jobType))
            if e.currentJob.fieldId then
                setXMLInt(xmlFile, base .. ".currentJob#fieldId", e.currentJob.fieldId)
            end
        end
    end
    return true
end

function EmployeeManager:loadFromXMLFile(xmlFile, key)
    CustomUtils:debug("[EmployeeManager] loadFromXMLFile()")
    -- Clear existing employees before loading
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
        emp.isHired = Utils.getNoNil(getXMLBool(xmlFile, base .. "#isHired"), true) -- Assume loaded employees are hired
        emp.workTime = Utils.getNoNil(getXMLFloat(xmlFile, base .. "#workTime"), 0)
        emp.kmDriven = Utils.getNoNil(getXMLFloat(xmlFile, base .. "#kmDriven"), 0)

        local jobType = getXMLString(xmlFile, base .. ".currentJob#jobType")
        local fieldId = getXMLInt(xmlFile, base .. ".currentJob#fieldId")
        if jobType ~= nil then
            emp.currentJob = { jobType = jobType }
            if fieldId ~= nil then emp.currentJob.fieldId = fieldId end
        end
        table.insert(self.employees, emp)
        i = i + 1
    end
    
    -- Generate available employees pool
    local numToGenerate = 10 - #self.employees
    if numToGenerate > 0 then
        for i = 1, numToGenerate do
            self:generateRandomEmployee()
        end
    end
end

function EmployeeManager:writeStream(streamId, connection)
    CustomUtils:debug("[EmployeeManager] writeStream()")
    streamWriteInt32(streamId, #self.employees)
    for _, employee in ipairs(self.employees) do
        employee:writeStream(streamId, connection)
    end
end

function EmployeeManager:readStream(streamId, connection)
    CustomUtils:debug("[EmployeeManager] readStream()")
    local numEmployees = streamReadInt32(streamId)
    self.employees = {}
    for _ = 1, numEmployees do
        local employee = Employee.new(0, "", {})
        employee:readStream(streamId, connection)
        table.insert(self.employees, employee)
    end
end
