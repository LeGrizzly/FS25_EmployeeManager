Employee = {}

local Employee_mt = Class(Employee)

Employee.TRAITS = {
    CAREFUL       = { nameKey = "em_trait_careful",       wearMult = 0.85 },
    RECKLESS      = { nameKey = "em_trait_reckless",      wearMult = 1.20, speedMult = 1.10 },
    FUEL_SAVER    = { nameKey = "em_trait_fuel_saver",    fuelMult = 0.85 },
    QUICK_LEARNER = { nameKey = "em_trait_quick_learner", xpMult = 1.50 },
    HARD_WORKER   = { nameKey = "em_trait_hard_worker",   speedMult = 1.10 },
    FRUGAL        = { nameKey = "em_trait_frugal",        wageMult = 0.90 },
}

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
    self.taskQueue = {}
    self.shiftStart = 6
    self.shiftEnd = 18

    self.trait = nil
    self.lastTrainingDay = 0
    self.totalWagesPaid = 0
    self.tasksCompleted = 0
    return self
end

function Employee:addExperience(skillName, amount)
    if self.skills[skillName] == nil or self.skills[skillName] >= 5 then
        return false
    end

    local xpMult = self:getTraitMultiplier("xpMult")
    self.skillXP[skillName] = (self.skillXP[skillName] or 0) + (amount * xpMult)
    local xpNeeded = self.skills[skillName] * 100

    if self.skillXP[skillName] >= xpNeeded then
        self.skillXP[skillName] = self.skillXP[skillName] - xpNeeded
        self.skills[skillName] = self.skills[skillName] + 1
        CustomUtils:info("[Employee] %s leveled up %s to level %d!", self.name, skillName, self.skills[skillName])
        g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
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

function Employee:getBaseHourlyWage()
    return 15 + ((self.skills.driving or 0) * 2) + ((self.skills.harvesting or 0) * 2) + ((self.skills.technical or 0) * 1)
end

function Employee:getHourlyWage()
    local base = self:getBaseHourlyWage()
    local traitMult = self:getTraitMultiplier("wageMult")
    local expMult = math.min(1.25, 1.0 + (self.workTime / 500))
    return base * traitMult * expMult
end

function Employee:getTechnicalMultiplier()
    local skill = math.max(1, math.min(5, self.skills.technical or 1))
    local baseMult = 1.0 - ((skill - 1) * 0.125)
    local traitWear = self:getTraitMultiplier("wearMult")
    return baseMult * traitWear
end

function Employee:getTraitMultiplier(property)
    if self.trait == nil then return 1.0 end
    local traitDef = Employee.TRAITS[self.trait]
    if traitDef == nil then return 1.0 end
    return traitDef[property] or 1.0
end

function Employee:getTraitName()
    if self.trait == nil then return nil end
    local traitDef = Employee.TRAITS[self.trait]
    if traitDef == nil then return self.trait end
    return g_i18n:getText(traitDef.nameKey)
end

function Employee:getTrainingCost(skillName)
    local currentLevel = self.skills[skillName] or 1
    return 500 * currentLevel
end

function Employee:canTrain(skillName, currentDay)
    local level = self.skills[skillName]
    if level == nil or level >= 5 then return false, "max_level" end
    if (currentDay - self.lastTrainingDay) < 3 then return false, "cooldown" end
    return true, "ok"
end

function Employee:train(skillName, currentDay)
    if self.skills[skillName] == nil or self.skills[skillName] >= 5 then return false end
    self.skills[skillName] = self.skills[skillName] + 1
    self.skillXP[skillName] = 0
    self.lastTrainingDay = currentDay
    CustomUtils:info("[Employee] %s trained %s to level %d", self.name, skillName, self.skills[skillName])
    g_messageCenter:publish(MessageType.EMPLOYEE_ADDED)
    return true
end

function Employee:updateWorkTime(dt)
    if self.isHired and self.currentJob ~= nil then
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
        isRenting = self.isRenting,
        taskQueue = self.taskQueue,
        shiftStart = self.shiftStart,
        shiftEnd = self.shiftEnd,
        trait = self.trait,
        lastTrainingDay = self.lastTrainingDay,
        totalWagesPaid = self.totalWagesPaid,
        tasksCompleted = self.tasksCompleted,
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
    e.taskQueue = data.taskQueue or {}
    e.shiftStart = data.shiftStart or 6
    e.shiftEnd = data.shiftEnd or 18
    e.trait = data.trait
    e.lastTrainingDay = data.lastTrainingDay or 0
    e.totalWagesPaid = data.totalWagesPaid or 0
    e.tasksCompleted = data.tasksCompleted or 0
    return e
end

function Employee:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.id)
    streamWriteString(streamId, self.name)
    streamWriteBool(streamId, self.isHired)
    streamWriteInt32(streamId, self.assignedVehicleId or 0)
    local queue = self.taskQueue or {}
    streamWriteInt32(streamId, #queue)
    for _, taskName in ipairs(queue) do
        streamWriteString(streamId, taskName)
    end
    streamWriteInt32(streamId, self.shiftStart or 6)
    streamWriteInt32(streamId, self.shiftEnd or 18)
    streamWriteString(streamId, self.trait or "")
    streamWriteInt32(streamId, self.lastTrainingDay or 0)
    streamWriteFloat32(streamId, self.totalWagesPaid or 0)
    streamWriteInt32(streamId, self.tasksCompleted or 0)
end

function Employee:readStream(streamId, connection)
    self.id = streamReadInt32(streamId)
    self.name = streamReadString(streamId)
    self.isHired = streamReadBool(streamId)
    local assignedVehicleId = streamReadInt32(streamId)
    if assignedVehicleId > 0 then
        self.assignedVehicleId = assignedVehicleId
    else
        self.assignedVehicleId = nil
    end
    local queueCount = streamReadInt32(streamId)
    self.taskQueue = {}
    for _ = 1, queueCount do
        table.insert(self.taskQueue, streamReadString(streamId))
    end
    self.shiftStart = streamReadInt32(streamId)
    self.shiftEnd = streamReadInt32(streamId)
    local trait = streamReadString(streamId)
    self.trait = (trait ~= "") and trait or nil
    self.lastTrainingDay = streamReadInt32(streamId)
    self.totalWagesPaid = streamReadFloat32(streamId)
    self.tasksCompleted = streamReadInt32(streamId)
end

return Employee
