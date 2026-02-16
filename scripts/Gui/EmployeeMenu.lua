EmployeeMenu = {}

local EmployeeMenu_mt = Class(EmployeeMenu, YesNoDialog)

function EmployeeMenu.new(target, custom_mt)
    local self = YesNoDialog.new(target, custom_mt or EmployeeMenu_mt)
    self.selectedEmployeeId = nil
    return self
end

function EmployeeMenu:onOpen()
    EmployeeMenu:superClass().onOpen(self)
    EmployeeUtils.debugPrint("--- Menu Ouvert ---")
    self:refreshEmployeeList()
end

function EmployeeMenu:onClose()
    EmployeeMenu:superClass().onClose(self)
    EmployeeUtils.debugPrint("--- Menu Fermé ---")
end

function EmployeeMenu:refreshEmployeeList()
    EmployeeUtils.debugPrint("--- Rafraichissement de la liste (NON IMPLEMENTE) ---")
end

function EmployeeMenu:onClickHire()
    EmployeeUtils.debugPrint("--- Clic sur Engager ---")
    local randomName = "Employé #" .. math.random(100, 999)
    local randomSkills = {
        driving = math.random(1, 5),
        harvesting = math.random(1, 5),
        technical = math.random(1, 5)
    }
    g_employeeManager:hireEmployee(randomName, randomSkills)
    self:refreshEmployeeList()
end

function EmployeeMenu:onClickFire()
    EmployeeUtils.debugPrint("--- Clic sur Virer ---")
    if self.selectedEmployeeId ~= nil then
        g_employeeManager:fireEmployee(self.selectedEmployeeId)
        self.selectedEmployeeId = nil
        self:refreshEmployeeList()
    else
        EmployeeUtils.debugPrint("--- Aucun employé sélectionné pour le licenciement ---")
    end
end
