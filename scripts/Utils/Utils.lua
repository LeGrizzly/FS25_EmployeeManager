EmployeeUtils = {}

EmployeeUtils.showDebug = false

function EmployeeUtils.debugPrint(a, b, c)
    local tag, message, force = nil, nil, false
    if b == nil then
        message = a
        force = c or false
    else
        tag = a
        message = b
        force = c or false
    end

    local enabled = EmployeeUtils.showDebug
    if not enabled and rawget(_G, "EmployeeManagerRegister") ~= nil then
        enabled = EmployeeManagerRegister.showDebug or EmployeeManagerRegister.showLoading or enabled
    end
    if not enabled and not force then
        return
    end

    if tag then
        print('['..tostring(tag)..'] '..tostring(message))
    else
        print(tostring(message))
    end
end

return EmployeeUtils
