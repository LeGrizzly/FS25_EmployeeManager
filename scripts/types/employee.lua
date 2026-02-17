Employee = {}

local Employee_mt = Class(Employee)

function Employee.new(id, name, skills)
    local self = setmetatable({}, Employee_mt)
    self.id = id or 0
    self.name = name or ("Employee_" .. tostring(self.id))
    self.skills = skills or { driving = 1, harvesting = 1, technical = 1 }
    
    self.isHired = false
    self.assignedVehicle = nil
    self.assignedField = nil
    self.workTime = 0
    self.kmDriven = 0
    self.currentJob = nil
    self.isRenting = false
    return self
end

function Employee:assignVehicle(vehicle)
    self.assignedVehicle = vehicle
end

function Employee:unassignVehicle()
    self.assignedVehicle = nil
end

function Employee:getDailyWage()
    local baseWage = 50
    local skillSum = (self.skills.driving or 0) + (self.skills.harvesting or 0) + (self.skills.technical or 0)
    return baseWage + (skillSum * 10)
end

function Employee:getFullName()
    return self.name
end

function Employee:setJob(jobTable)
    self.currentJob = jobTable
end

function Employee:clearJob()
    self.currentJob = nil
end

function Employee:toTable()
    return {
        id = self.id,
        name = self.name,
        skills = self.skills,
        assignedVehicle = (self.assignedVehicle ~= nil) and self.assignedVehicle.rootNode or nil,
        currentJob = self.currentJob,
        isRenting = self.isRenting
    }
end

function Employee.fromTable(data)
    if data == nil then
        return nil
    end
    local e = Employee.new(data.id, data.name, data.skills)
    e.currentJob = data.currentJob
    e.isRenting = data.isRenting
    return e
end

return Employee
