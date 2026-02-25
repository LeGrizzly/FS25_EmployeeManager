EMGui = {}

local EMGui_mt = Class(EMGui, TabbedMenu)

function EMGui:new(messageCenter, l18n, inputManager)
    local self = TabbedMenu.new(nil, EMGui_mt, messageCenter, l18n, inputManager)

    self.messageCenter = messageCenter
    self.l18n          = l18n
    self.inputManager  = g_inputBinding

    return self
end

function EMGui:onGuiSetupFinished()
    EMGui:superClass().onGuiSetupFinished(self)

    self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)

    self.pageEmployees:initialize()
    self.pageWorkflows:initialize()
    self.pageFields:initialize()
    self.pageVehicles:initialize()

    self:setupPages(self)
    self:setupMenuButtonInfo()
end

function EMGui:setupPages(gui)
    local pages = {
        { gui.pageEmployees, "ingameMenu/tab_character" },
        { gui.pageWorkflows, "ingameMenu/tab_contracts" },
        { gui.pageFields,    "ingameMenu/tab_map" },
        { gui.pageVehicles,  "ingameMenu/tab_vehicles" },
    }

    for idx, thisPage in ipairs(pages) do
        local page, sliceId = unpack(thisPage)
        gui:registerPage(page, idx)
        gui:addPageTab(page, nil, nil, sliceId)
    end

    gui:rebuildTabList()
end

function EMGui:setupMenuButtonInfo()
    local onButtonBackFunction = self.clickBackCallback

    self.defaultMenuButtonInfo = {
        {
            inputAction = InputAction.MENU_BACK,
            text        = g_i18n:getText("button_back"),
            callback    = onButtonBackFunction,
        },
    }

    self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1]

    self.defaultButtonActionCallbacks = {
        [InputAction.MENU_BACK] = onButtonBackFunction,
    }
end

function EMGui:onOpen()
    EMGui:superClass().onOpen(self)
    self.pageEmployees:refresh()
    self.pageWorkflows:refresh()
    self.pageFields:refresh()
    self.pageVehicles:refresh()
end

function EMGui:onClose()
    CustomUtils:info("[EMGui] onClose()")
    EMGui:superClass().onClose(self)
end

function EMGui:onButtonBack()
    CustomUtils:info("[EMGui] onButtonBack()")
    self:exitMenu()
end

function EMGui:onClickBack()
    CustomUtils:info("[EMGui] onClickBack()")
    self:exitMenu()
end

function EMGui:exitMenu()
    self:changeScreen()
end
