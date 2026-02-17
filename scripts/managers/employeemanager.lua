EmployeeManager = {}

local EmployeeManager_mt = Class(EmployeeManager)

function EmployeeManager:new(mission)
    local self = setmetatable({}, EmployeeManager_mt)
    self.mission = mission
    self.employees = {}
    self.firstNames = {"John", "Peter", "Mike", "David", "Chris", "Paul", "Mark", "James", "Andrew", "Daniel"}
    self.lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"}
    return self
end

function EmployeeManager:onMissionInitialize(baseDirectory)
    EmployeeUtils.debugPrint("--- Mission Initializing! ---")
    print("[FS25_EmployeeManager] EmployeeManager: Mission initialized with base directory: " .. tostring(baseDirectory))
end

function EmployeeManager:getEmployees()
    return self.employees
end

function EmployeeManager:hireEmployee(name, skills)
    local id = 1
    for _, e in ipairs(self.employees) do
        if e.id >= id then
            id = e.id + 1
        end
    end
    local emp = Employee.new(id, name, skills)
    table.insert(self.employees, emp)
    EmployeeUtils.debugPrint(string.format("--- Hired employee id=%d name=%s ---", emp.id, emp.name))
    g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
    return emp
end

function EmployeeManager:fireEmployee(id)
    for idx, e in ipairs(self.employees) do
        if e.id == id then
            table.remove(self.employees, idx)
            EmployeeUtils.debugPrint(string.format("--- Fired employee id=%d ---", id))
            g_messageCenter:publish(MessageType.EMPLOYEE_REMOVED)
            return true
        end
    end
    return false
end

function EmployeeManager:generateRandomEmployee()
    math.randomseed(g_currentMission.time + math.random(1, 1000))
    local firstName = self.firstNames[math.random(#self.firstNames)]
    local lastName = self.lastNames[math.random(#self.lastNames)]
    local name = firstName .. " " .. lastName
    local skills = {
        driving = math.random(1, 5),
        harvesting = math.random(1, 5),
        technical = math.random(1, 5)
    }
    self:hireEmployee(name, skills)
end

function EmployeeManager:saveToXMLFile(xmlFile, key)
    local empKey = key .. ".employees"
    for i, e in ipairs(self.employees) do
        local base = string.format("%s.employee(%d)", empKey, i-1)
        setXMLInt(xmlFile, base .. "#id", e.id)
        setXMLString(xmlFile, base .. "#name", e.name)

        setXMLInt(xmlFile, base .. ".skills#driving", e.skills.driving)
        setXMLInt(xmlFile, base .. ".skills#harvesting", e.skills.harvesting)
        setXMLInt(xmlFile, base .. ".skills#technical", e.skills.technical)
        if e.currentJob ~= nil then
            setXMLString(xmlFile, base .. ".currentJob#jobType", tostring(e.currentJob.jobType))
            if e.currentJob.fieldId then
                setXMLInt(xmlFile, base .. ".currentJob#fieldId", e.currentJob.fieldId)
            end
        end
        setXMLBool(xmlFile, base .. "#isRenting", e.isRenting)
    end
    return true
end

function EmployeeManager:loadFromXMLFile(xmlFile, key)
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

        local jobType = getXMLString(xmlFile, base .. ".currentJob#jobType")
        local fieldId = getXMLInt(xmlFile, base .. ".currentJob#fieldId")
        if jobType ~= nil then
            emp.currentJob = { jobType = jobType }
            if fieldId ~= nil then emp.currentJob.fieldId = fieldId end
        end
        emp.isRenting = Utils.getNoNil(getXMLBool(xmlFile, base .. "#isRenting"), false)
        table.insert(self.employees, emp)
        i = i + 1
    end
    EmployeeUtils.debugPrint(string.format("--- Loaded %d employees from savegame ---", #self.employees))
    
    if #self.employees == 0 then
        EmployeeUtils.debugPrint("--- No employees found in savegame, generating 5 random employees. ---")
        for i = 1, 5 do
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
        table.insert(self.employees, employee)
    end
end
