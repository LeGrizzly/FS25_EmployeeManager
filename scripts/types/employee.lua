Employee = {}

local Employee_mt = Class(Employee)

function Employee.new(id, name, skills)
    local self = setmetatable({}, Employee_mt)
    self.id = id or 0
    self.name = name or ("Employee_" .. tostring(self.id))
    self.skills = skills or { driving = 1, harvesting = 1, technical = 1 }
    self.skillXP = { driving = 0, harvesting = 0, technical = 0 }
    
    self.isHired = false
    self.assignedVehicle = nil
    self.assignedVehicleId = nil
    self.assignedField = nil
    self.workTime = 0
    self.kmDriven = 0
    self.currentJob = nil
    self.targetCrop = nil
    self.targetFieldId = nil
    self.isRenting = false
    self.isAutonomous = false
    return self
end

function Employee:addExperience(skillName, amount)
    if self.skills[skillName] == nil or self.skills[skillName] >= 5 then
        return false
    end

    self.skillXP[skillName] = (self.skillXP[skillName] or 0) + amount
    local xpNeeded = self.skills[skillName] * 100 -- Level 1 -> 2: 100xp, 2 -> 3: 200xp, etc.

    if self.skillXP[skillName] >= xpNeeded then
        self.skillXP[skillName] = self.skillXP[skillName] - xpNeeded
        self.skills[skillName] = self.skills[skillName] + 1
        CustomUtils:info("[Employee] %s leveled up %s to level %d!", self.name, skillName, self.skills[skillName])
        g_messageCenter:publish(MessageType.EMPLOYEE_ADDED) -- Trigger UI refresh
        return true
    end
    return false
end

function Employee:assignVehicle(vehicle)
    if vehicle ~= nil then
        self.assignedVehicle = vehicle
        self.assignedVehicleId = vehicle.id
        return true
    end
    return false
end

function Employee:unassignVehicle()
    self.assignedVehicle = nil
    self.assignedVehicleId = nil
end

function Employee:getDailyWage()
    local baseWage = 50
    local skillSum = (self.skills.driving or 0) + (self.skills.harvesting or 0) + (self.skills.technical or 0)
    return baseWage + (skillSum * 10)
end

function Employee:getHourlyWage()
    -- Base hourly wage + skill bonus
    local baseHourly = 15
    local skillBonus = ((self.skills.driving or 0) * 2) + ((self.skills.harvesting or 0) * 2) + ((self.skills.technical or 0) * 1)
    return baseHourly + skillBonus
end

function Employee:getTechnicalMultiplier()
    -- Level 1: 1.0x (normal wear)
    -- Level 5: 0.5x (50% less wear)
    local skill = math.max(1, math.min(5, self.skills.technical or 1))
    return 1.0 - ((skill - 1) * 0.125) 
end

function Employee:updateWorkTime(dt)
    if self.isHired and self.currentJob ~= nil then
        -- dt is in milliseconds
        local hours = dt / (1000 * 60 * 60)
        self.workTime = self.workTime + hours
        return hours
    end
    return 0
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
        assignedVehicleId = self.assignedVehicleId,
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
    e.assignedVehicleId = data.assignedVehicleId
    return e
end

function Employee:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.id)
    streamWriteString(streamId, self.name)
    streamWriteBool(streamId, self.isHired)
    streamWriteInt32(streamId, self.assignedVehicleId or 0)
    -- Add other fields as needed
end

function Employee:readStream(streamId, connection)
    self.id = streamReadInt32(streamId)
    self.name = streamWriteString(streamId)
    self.isHired = streamReadBool(streamId)
    local assignedVehicleId = streamReadInt32(streamId)
    if assignedVehicleId > 0 then
        self.assignedVehicleId = assignedVehicleId
        -- Note: Vehicle might not be resolvable yet if stream order matters, handled in manager or later
    else
        self.assignedVehicleId = nil
    end
end

return Employee
