SimpleStatusHUD = {}
local SimpleStatusHUD_mt = Class(SimpleStatusHUD)

function SimpleStatusHUD.new()
    local self = setmetatable({}, SimpleStatusHUD_mt)
    self.isVisible = false
    self.bgOverlay = nil
    self.posX = 0.82
    self.posY = 0.6
    self.width = 0.17
    self.height = 0.3
    return self
end

function SimpleStatusHUD:load()
    self.bgOverlay = Overlay.new(g_baseUIFilename, self.posX, self.posY, self.width, self.height)
    self.bgOverlay:setUVs(GuiUtils.getUVs({0, 0, 1, 1}))
    self.bgOverlay:setColor(0, 0, 0, 0.75)
end

function SimpleStatusHUD:toggle()
    self.isVisible = not self.isVisible
end

function SimpleStatusHUD:draw()
    if not self.isVisible or g_gui.currentGuiName ~= nil then return end

    if self.bgOverlay then
        self.bgOverlay:render()
    end

    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)

    local x = self.posX + 0.005
    local y = self.posY + self.height - 0.025
    local lineHeight = 0.018

    setTextBold(true)
    renderText(x, y, 0.015, "EMPLOYEE MANAGER STATUS")
    y = y - (lineHeight * 1.5)
    setTextBold(false)

    if g_employeeManager then
        local employees = g_employeeManager.employees
        if employees then
            for _, emp in ipairs(employees) do
                if emp.isHired then
                    setTextColor(1, 1, 1, 1)
                    renderText(x, y, 0.012, string.format("[%d] %s", emp.id, emp.name))
                    
                    local status = "Idle"
                    local color = {0.7, 0.7, 0.7, 1}
                    
                    if emp.currentJob then
                        status = emp.currentJob.type or "Unknown"
                        if emp.currentJob.workType then
                            status = status .. ": " .. emp.currentJob.workType
                        end
                        color = {0, 1, 0, 1}
                    elseif emp.targetCrop then
                        status = "Auto: Waiting"
                        color = {1, 1, 0, 1}
                    end

                    setTextColor(unpack(color))
                    renderText(x + 0.08, y, 0.012, status)

                    y = y - lineHeight

                    if emp.assignedVehicleId then
                        local v = g_employeeManager:getVehicleById(emp.assignedVehicleId)
                        if v then
                            setTextColor(0.8, 0.8, 0.8, 1)
                            renderText(x + 0.01, y, 0.010, "- " .. v:getName())
                            y = y - lineHeight
                        end
                    end
                    
                    y = y - (lineHeight * 0.5)
                end
            end
        end
    else
        renderText(x, y, 0.012, "Manager not loaded")
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function SimpleStatusHUD:delete()
    if self.bgOverlay then
        self.bgOverlay:delete()
    end
end
