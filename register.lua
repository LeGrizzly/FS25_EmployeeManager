source(Utils.getFilename("scripts/Utils/Utils.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/EmployeeManager.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Employee/Employee.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Gui/EmployeeMenu.lua", g_currentModDirectory))

EmployeeManagerRegister = {}

EmployeeManagerRegister.name = g_currentModName
EmployeeManagerRegister.path = g_currentModDirectory
EmployeeManagerRegister.globalKey = "EMPLOYEE_MANAGER_REGISTER"
EmployeeManagerRegister.version = g_modManager:getModByName(g_currentModName).version

EmployeeManagerRegister.showDebug = false
EmployeeManagerRegister.showLoading = false
EmployeeManagerRegister.isInitialized = false

function EmployeeManagerRegister:loadMap(name)
    Logging.info("[%s] Loaded mod version %s", self.name, tostring(self.version))
    -- Ne rien faire ici, l'initialisation se fera dans :update()
end

function EmployeeManagerRegister:update(dt)
    if not self.isInitialized and g_mission ~= nil and g_mission.ingameMenuAppended ~= nil then
        self.isInitialized = true -- Pour ne l'exécuter qu'une fois
        g_employeeManager = EmployeeManager:new(g_currentMission)
        g_mission.ingameMenuAppended:add(self.registerIngameMenu, self)
    end
end

function EmployeeManagerRegister:registerIngameMenu()
    if g_mission ~= nil and g_mission.ingameMenu ~= nil then
        g_mission.ingameMenu:addMenu(
            "EmployeeIngameMenu",
            g_i18n:getText("EM_employee_management"), 
            5 
        )
        g_mission.ingameMenuAppended:remove(self.registerIngameMenu, self)
    end
end

function EmployeeManagerRegister:deleteMap()
end

function EmployeeManagerRegister:keyEvent(unicode, sym, modifier, isDown)
end

function EmployeeManagerRegister:mouseEvent(posX, posY, isDown, isUp, button)
end

function EmployeeManagerRegister:update(dt)
end

function EmployeeManagerRegister:draw()
end

function EmployeeManagerRegister.AddCustomStrings()
	local i = 0
	local xmlFile = loadXMLFile("modDesc", g_currentModDirectory.."modDesc.xml")
	while true do
		local key = string.format("modDesc.l10n.text(%d)", i)
		
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		
		local name = getXMLString(xmlFile, key.."#name")
		local text = getXMLString(xmlFile, key.."."..g_languageShort)
		
		if name then
			g_i18n:setText(name, text)
			EmployeeUtils.debugPrint(EmployeeManagerRegister.name, tostring(name)..": "..tostring(text))
		end
		
		i = i + 1
	end
end
EmployeeManagerRegister.AddCustomStrings()

addModEventListener(EmployeeManagerRegister)
