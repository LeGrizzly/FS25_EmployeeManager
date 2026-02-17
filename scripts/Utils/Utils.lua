EmployeeUtils = {}

EmployeeUtils.showDebug = true

function EmployeeUtils.debugPrint(message)
    if not EmployeeUtils.showDebug then
        return
    end

    local msg = tostring(message or "")
    print(string.format('[%s] %s', g_modName, msg))
end

return EmployeeUtils
