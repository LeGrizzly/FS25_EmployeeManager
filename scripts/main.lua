print("Loading main.lua")

g_modName = g_currentModName
g_modDirectory = g_currentModDirectory

MessageType.EMPLOYEE_ADDED = nextMessageTypeId()
MessageType.EMPLOYEE_REMOVED = nextMessageTypeId()

source(g_modDirectory .. "scripts/utils/Utils.lua")
source(g_modDirectory .. "scripts/types/employee.lua")
source(g_modDirectory .. "scripts/events/HireEmployeeEvent.lua")
source(g_modDirectory .. "scripts/events/FireEmployeeEvent.lua")

source(g_modDirectory .. "scripts/gui/EmployeeRenderer.lua")
source(g_modDirectory .. "scripts/gui/MenuEmployeeManager.lua")

source(g_modDirectory .. "scripts/managers/employeemanager.lua")
source(g_modDirectory .. "scripts/ModGui.lua")

source(g_modDirectory .. "scripts/modcontroller.lua")
