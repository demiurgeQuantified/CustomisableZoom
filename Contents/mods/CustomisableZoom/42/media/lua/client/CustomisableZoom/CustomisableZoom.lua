local Version = require("Starlit/Version")
local TaskManager = require("Starlit/TaskManager")

local CORE = getCore()

local MAX_ZOOM_LEVELS = 10

---@param a number
---@param b number
---@return boolean
local sortHighestFirst = function(a, b)
    return a > b
end

local CustomisableZoom = {}

CustomisableZoom.zoomLevelOptions = table.newarray()
CustomisableZoom.zoomEnabledOptions = table.newarray()

CustomisableZoom.refreshZoom = function()
    if not isIngameState() then return end

    ---@type number[]
    local zoomLevels = table.newarray()
    ---@type {number : true}
    local activeZoomLevels = {}
    for i = 1, MAX_ZOOM_LEVELS do
        if CustomisableZoom.zoomEnabledOptions[i]:getValue() == true then
            local zoomLevel = CustomisableZoom.zoomLevelOptions[i]:getValue()
            if not activeZoomLevels[zoomLevel] then
                table.insert(zoomLevels, zoomLevel)
                activeZoomLevels[zoomLevel] = true
            end
        end
    end

    if #zoomLevels >= 1 then
        table.sort(zoomLevels, sortHighestFirst)
    else
        -- weirdo...
        zoomLevels[1] = 1
    end

    local maxPlayerIndex = getNumActivePlayers() - 1
    -- reset the zoom level if a player's zoom level is now invalid (otherwise it gets stuck)
    for i = 0, maxPlayerIndex do
        local currentZoomLevel = CORE:getZoom(i)
        if not activeZoomLevels[currentZoomLevel] then
            -- lol
            CORE:setZoomEnalbed(false)
            -- must wait a tick to actually apply
            TaskManager.delayTicks(function()
                CORE:setZoomEnalbed(true)
                -- if zoom 1 isn't enabled, trigger a zoom away from it
                if not activeZoomLevels[1] then
                    local fixedZoomLevels = copyTable(zoomLevels)
                    if not activeZoomLevels[1] then
                        table.insert(fixedZoomLevels, 1)
                    end
                    setZoomLevels(unpack(fixedZoomLevels))

                    CORE:doZoomScroll(0, 1)
                    setZoomLevels(unpack(zoomLevels))
                end
            end, 1)
            return
        end
    end

    setZoomLevels(unpack(zoomLevels))
end

local options = PZAPI.ModOptions:create("CustomisableZoom", getText("IGUI_CustomisableZoom"))
options.apply = CustomisableZoom.refreshZoom
options:addDescription(getText("IGUI_CustomisableZoom_options_description"))

for i = 1, MAX_ZOOM_LEVELS do
    CustomisableZoom.zoomEnabledOptions[i] = options:addTickBox(
        "ZoomLevelEnabled" .. tostring(i),
        getText("IGUI_CustomisableZoom_options_ZoomLevelEnabled", i),
        true
    )
    CustomisableZoom.zoomLevelOptions[i] = options:addSlider(
        "ZoomLevel" .. tostring(i), getText("IGUI_CustomisableZoom_options_ZoomLevel", i),
        0.01, 5, 0.01, 0.25 * i)
end

CustomisableZoom.onGameStart = function()
    Version.ensureVersion(1, 3, 0)
    -- need to wait for the player to be added
    TaskManager.delayTicks(CustomisableZoom.refreshZoom, 1)
end

Events.OnGameStart.Add(CustomisableZoom.onGameStart)

-- new players will spawn with zoom 1, which may not be valid
Events.OnCreatePlayer.Add(CustomisableZoom.refreshZoom)

return CustomisableZoom