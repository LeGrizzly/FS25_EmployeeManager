CustomUtils = {}

local _print = print

CustomUtils.showDebug = true

CustomUtils.tag = {
    INFO = "INFO",
    ERROR = "ERROR",
    DEBUG = "DEBUG"
}

local function formatWithArgs(message, ...)
    if select('#', ...) > 0 then
        return string.format(message, ...)
    end

    return tostring(message)
end

function CustomUtils:_log(tag, message, ...)
    if not self.showDebug then
        return
    end

    local msg = formatWithArgs(message, ...)
    local modName = g_modName or "FS25_EmployeeManager"

    if tag and tag ~= "" then
        _print(string.format('[%s] %s: %s', modName, tag, msg))
    else
        _print(string.format('[%s] %s', modName, msg))
    end
end

function CustomUtils:info(message, ...)
    self:_log(self.tag.INFO, message, ...)
end

function CustomUtils:error(message, ...)
    self:_log(self.tag.ERROR, message, ...)
end

function CustomUtils:debug(message, ...)
    self:_log(self.tag.DEBUG, message, ...)
end

-- Preserve legacy behaviour for raw prints
function CustomUtils:print(message, ...)
    if not self.showDebug then
        return
    end

    local msg = formatWithArgs(message, ...)
    local modName = g_modName or "FS25_EmployeeManager"
    _print(string.format('[%s] %s', modName, msg))
end
