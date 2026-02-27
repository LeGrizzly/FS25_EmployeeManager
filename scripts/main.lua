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
source(g_modDirectory .. "scripts/gui/TaskListItemRenderer.lua")
source(g_modDirectory .. "scripts/gui/MenuEmployeeManager.lua")

source(g_modDirectory .. "scripts/gui/EMEmployeeFrame.lua")
source(g_modDirectory .. "scripts/gui/EMWorkflowFrame.lua")
source(g_modDirectory .. "scripts/gui/EMFieldFrame.lua")
source(g_modDirectory .. "scripts/gui/EMVehicleFrame.lua")
source(g_modDirectory .. "scripts/gui/EMTrainingDialog.lua")
source(g_modDirectory .. "scripts/gui/EMGui.lua")

source(g_modDirectory .. "scripts/managers/commandmanager.lua")
source(g_modDirectory .. "scripts/managers/coursemanager.lua")
source(g_modDirectory .. "scripts/managers/cropmanager.lua")
source(g_modDirectory .. "scripts/managers/employeemanager.lua")
source(g_modDirectory .. "scripts/managers/jobmanager.lua")
source(g_modDirectory .. "scripts/managers/parkingmanager.lua")
source(g_modDirectory .. "scripts/extensions/WearableExtension.lua")
source(g_modDirectory .. "scripts/extensions/AIOverrideExtension.lua")
source(g_modDirectory .. "scripts/extensions/HelperNameExtension.lua")
source(g_modDirectory .. "scripts/gui/SimpleStatusHUD.lua")
source(g_modDirectory .. "scripts/ModGui.lua")

source(g_modDirectory .. "scripts/modcontroller.lua")

WearableExtension.init()
AIOverrideExtension.init()
HelperNameExtension.init()
