---@class ModGui
ModGui = {}

-- ModGui.TEXTURE_CONFIG_FILENAME = g_modDirectory .. 'textures/ui_elements.xml'

local ModGui_mt = Class(ModGui)

function ModGui.new()
    Logging.info("[ModGui] new()")
    local self = setmetatable({}, ModGui_mt)

    if g_client ~= nil then
        addConsoleCommand('emReloadGui', '', 'consoleReloadGui', self)
        addConsoleCommand('emGuiReloadFrames', '', 'consoleReloadFrames', self)
    end

    return self
end

function ModGui:load()
    if g_client == nil then
        return
    end

    -- Load GUI Profiles
    g_gui:loadProfiles(g_modDirectory .. "xml/gui/guiProfiles.xml")

    -- Load the Employee Manager in-game menu frame
    if not self:loadMenuFrame(MenuEmployeeManager) then
        Logging.warning('[EmployeeManager] ModGui:load() MenuEmployeeManager already loaded')
    end
end

function ModGui:loadMenuFrame(class)
    if class == nil then
        return false
    end

    local pageController = class.new()
    local pageName = class.MENU_PAGE_NAME

    if self[pageName] ~= nil then
        return false
    end

    if g_gui == nil or g_inGameMenu == nil then
        -- If global menu references are not yet available, delay loading.
        Logging.info('[EmployeeManager] g_gui or g_inGameMenu not ready, deferring menu load')
        return false
    end

    g_gui:loadGui(class.XML_FILENAME, class.CLASS_NAME, pageController, true)

    g_inGameMenu[pageName] = pageController
    g_inGameMenu.pagingElement:addElement(pageController)
    g_inGameMenu:registerPage(pageController, nil, function() return true end)
    g_inGameMenu:addPageTab(pageController, nil, nil, class.MENU_ICON_SLICE_ID)

    if pageController.initialize ~= nil then
        pageController:initialize()
    end

    self[pageName] = pageController

    pageController:updateAbsolutePosition()
    g_inGameMenu.pagingTabList:reloadData()

    return true
end

function ModGui:deleteMenuFrame(class)
    local pageName = class.MENU_PAGE_NAME
    if self[pageName] == nil then
        return false
    end

    local pageController = self[pageName]

    g_inGameMenu:setPageEnabled(class, false)
    local _, _, pageRoot, _ = g_inGameMenu:unregisterPage(class)
    g_inGameMenu.pagingElement:removeElement(pageRoot)

    pageRoot:delete()
    pageController:delete()

    FocusManager:deleteGuiFocusData(class.CLASS_NAME)

    g_inGameMenu[pageName] = nil
    self[pageName] = nil

    return true
end

function ModGui:onMapLoaded()
    if g_client ~= nil then
        -- ensure tab list alignment is reasonable
        if g_inGameMenu ~= nil and g_inGameMenu.pagingTabList ~= nil then
            g_inGameMenu.pagingTabList.listItemAlignment = SmoothListElement.ALIGN_START
        end

        self:load()
    end
end

function ModGui:consoleReloadGui()
    if g_server ~= nil and not g_currentMission.missionDynamicInfo.isMultiplayer then
        self:load()
        return 'Reloaded GUI'
    end

    return 'Only available in single player'
end

function ModGui:consoleReloadFrames()
    if g_server ~= nil and not g_currentMission.missionDynamicInfo.isMultiplayer then
        g_gui:showGui("InGameMenu")

        if self:deleteMenuFrame(MenuEmployeeManager) then
            g_gui.currentlyReloading = true
            self:loadMenuFrame(MenuEmployeeManager)
            g_gui.currentlyReloading = false
            g_inGameMenu:rebuildTabList()
            g_inGameMenu.pagingElement:updatePageMapping()
            return 'Reloaded MenuEmployeeManager'
        end
    end

    return 'Only available in single player'
end

g_modGui = ModGui.new()
