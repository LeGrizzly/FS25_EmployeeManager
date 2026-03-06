DBAPIPersistence = {}
DBAPIPersistence.__index = DBAPIPersistence
DBAPIPersistence.NAMESPACE = "FS25_EmployeeManager"

function DBAPIPersistence:new()
    return setmetatable({}, self)
end

function DBAPIPersistence:getName()
    return "DBAPI"
end

function DBAPIPersistence:getAPI()
    if g_globalMods then
        return g_globalMods["FS25_DBAPI"]
    end
    return nil
end

function DBAPIPersistence:isAvailable()
    if g_currentMission and g_currentMission.missionDynamicInfo and g_currentMission.missionDynamicInfo.isMultiplayer then
        CustomUtils:debug("[DBAPIPersistence] Multiplayer detected, not available")
        return false
    end

    local api = self:getAPI()
    if api == nil then
        CustomUtils:debug("[DBAPIPersistence] g_globalMods['FS25_DBAPI'] not found")
        return false
    end

    if not api.isReady() then
        CustomUtils:debug("[DBAPIPersistence] DBAPI present but not ready")
        return false
    end

    return true
end

function DBAPIPersistence:save(employeeManager, parkingManager)
    local api = self:getAPI()
    if api == nil then
        CustomUtils:error("[DBAPIPersistence] DBAPI not available for save")
        return false
    end

    local ns = self.NAMESPACE

    local employeeIds = {}
    for _, e in ipairs(employeeManager.employees) do
        table.insert(employeeIds, e.id)
        CustomUtils:debug("[DBAPIPersistence] Saving employee_%d (%s) isHired=%s vehicle=%s", e.id, e.name, tostring(e.isHired), tostring(e.assignedVehicleId))
        local data = e:toTable()
        local success, err = api.setValue(ns, "employee_" .. tostring(e.id), data)
        CustomUtils:debug("[DBAPIPersistence] setValue employee_%d => success=%s err=%s", e.id, tostring(success), tostring(err))
        if not success then
            CustomUtils:error("[DBAPIPersistence] Failed to save employee %d: %s", e.id, tostring(err))
            return false
        end
    end

    local success, err
    success, err = api.setValue(ns, "meta_employeeIds", employeeIds)
    CustomUtils:debug("[DBAPIPersistence] setValue meta_employeeIds => success=%s err=%s", tostring(success), tostring(err))
    if not success then
        CustomUtils:error("[DBAPIPersistence] Failed to save meta_employeeIds: %s", tostring(err))
        return false
    end

    api.setValue(ns, "meta_nextEmployeeId", employeeManager.nextEmployeeId)
    api.setValue(ns, "meta_lastPoolRefreshDay", employeeManager.lastPoolRefreshDay or 0)
    api.setValue(ns, "meta_lastPaymentPeriod", employeeManager.lastPaymentPeriod or 0)

    if parkingManager then
        local parkingData = {
            spots = parkingManager.spots,
            nextSpotId = parkingManager.nextSpotId,
        }
        api.setValue(ns, "parking", parkingData)
    end

    local hiredCount = 0
    for _, e in ipairs(employeeManager.employees) do
        if e.isHired then hiredCount = hiredCount + 1 end
    end
    CustomUtils:info("[DBAPIPersistence] Saved %d employees (%d hired) via DBAPI", #employeeManager.employees, hiredCount)
    return true
end

function DBAPIPersistence:load(employeeManager, parkingManager)
    local api = self:getAPI()
    if api == nil then
        CustomUtils:error("[DBAPIPersistence] DBAPI not available for load")
        return false
    end

    local ns = self.NAMESPACE

    local employeeIds = api.getValue(ns, "meta_employeeIds")
    if employeeIds == nil or type(employeeIds) ~= "table" or #employeeIds == 0 then
        CustomUtils:info("[DBAPIPersistence] No employee data found in DBAPI")
        return false
    end

    employeeManager.employees = {}
    local maxId = 0
    for _, id in ipairs(employeeIds) do
        local data = api.getValue(ns, "employee_" .. tostring(id))
        if data ~= nil then
            local emp = Employee.fromTable(data)
            if emp ~= nil then
                if emp.assignedVehicleId and emp.assignedVehicleId ~= 0 then
                    local vehicle = employeeManager:getVehicleById(emp.assignedVehicleId)
                    if vehicle then
                        emp:assignVehicle(vehicle)
                    end
                end
                table.insert(employeeManager.employees, emp)
                if emp.id > maxId then maxId = emp.id end
            end
        end
    end

    local nextId = api.getValue(ns, "meta_nextEmployeeId")
    employeeManager.nextEmployeeId = nextId or (maxId + 1)
    if employeeManager.nextEmployeeId <= maxId then
        employeeManager.nextEmployeeId = maxId + 1
    end

    employeeManager.lastPoolRefreshDay = api.getValue(ns, "meta_lastPoolRefreshDay") or 0
    employeeManager.lastPaymentPeriod = api.getValue(ns, "meta_lastPaymentPeriod") or 0

    if parkingManager then
        local parkingData = api.getValue(ns, "parking")
        if parkingData and type(parkingData) == "table" then
            parkingManager.spots = parkingData.spots or {}
            parkingManager.nextSpotId = parkingData.nextSpotId or 1
            CustomUtils:info("[DBAPIPersistence] Loaded %d parking spots", #parkingManager.spots)
        end
    end

    local hiredCount = 0
    for _, e in ipairs(employeeManager.employees) do
        if e.isHired then hiredCount = hiredCount + 1 end
    end
    CustomUtils:info("[DBAPIPersistence] Loaded %d employees (%d hired) via DBAPI", #employeeManager.employees, hiredCount)

    local numToGenerate = 10 - #employeeManager.employees
    if numToGenerate > 0 then
        CustomUtils:info("[DBAPIPersistence] Filling pool: generating %d candidates", numToGenerate)
        employeeManager:generateInitialPool(numToGenerate)
    end

    return #employeeManager.employees > 0
end
