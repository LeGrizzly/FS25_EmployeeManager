-- Setup global variables
g_modName = g_currentModName
g_modDirectory = g_currentModDirectory

-- Register message types used by the Employee Manager
MessageType.EMPLOYEE_ADDED = nextMessageTypeId()
MessageType.EMPLOYEE_REMOVED = nextMessageTypeId()

-- Load all mod scripts
source(g_modDirectory .. "scripts/utils/utils.lua")
source(g_modDirectory .. "scripts/types/employee.lua")
source(g_modDirectory .. "scripts/events/HireEmployeeEvent.lua")
source(g_modDirectory .. "scripts/events/FireEmployeeEvent.lua")
source(g_modDirectory .. "scripts/gui/frames/employeeingamemenuframe.lua")
source(g_modDirectory .. "scripts/managers/employeemanager.lua")
source(g_modDirectory .. "scripts/ModGui.lua")

-- if g_client ~= nil then
    -- g_modSettings:loadUserSettings()
    -- g_modGui:load()
    -- g_modHud:load()
-- end

source(g_modDirectory .. "scripts/modcontroller.lua")
