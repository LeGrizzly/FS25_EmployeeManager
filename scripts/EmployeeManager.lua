EmployeeManager = {}

local EmployeeManager_mt = Class(EmployeeManager)

function EmployeeManager:new(mission)
    local self = setmetatable({}, EmployeeManager_mt)
    self.mission = mission
    self.employees = {}
    return self
end

function EmployeeManager:loadMap(name)
    EmployeeUtils.debugPrint("--- Mod Chargé ! ---")
    
    self.employeeMenu = EmployeeMenu.new()
    local guiPath = Utils.getFilename("gui/employeeMenu.xml", g_currentModDirectory)
    EmployeeUtils.debugPrint(string.format("EmployeeManager: loading GUI from '%s'", tostring(guiPath)))
    g_gui:loadGui(guiPath, "EmployeeMenu", self.employeeMenu)
end

function EmployeeManager:onMissionInitialize(baseDirectory)
    EmployeeUtils.debugPrint("--- Initialisation de la mission ! ---")
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
    EmployeeUtils.debugPrint(string.format("--- Employé embauché id=%d name=%s ---", emp.id, emp.name))
    return emp
end

function EmployeeManager:fireEmployee(id)
    for idx, e in ipairs(self.employees) do
        if e.id == id then
            table.remove(self.employees, idx)
            EmployeeUtils.debugPrint(string.format("--- Employé viré id=%d ---", id))
            return true
        end
    end
    return false
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
    EmployeeUtils.debugPrint(string.format("--- Chargé %d employés depuis le savegame ---", #self.employees))
end
