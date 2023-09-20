-- WHAT A PAIN JUST TO ADD A CUSTOM COMMAND TO THE MAP COMMANDS!!!!!!!!!!
-- Only difference between this and the original is the CommandOrder part which is 2 lines of code (+1~1-16)
if onClient() then
    local CommandOrder = include("commandorder")
    function MapCommands.initUI()
        -- ships frame
        local barContainer = GalaxyMap():createContainer()

        local res = getResolution()

        local offset = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)

        local arrowUpRect, arrowDownRect = Rect(), Rect()

        arrowUpRect.lower = offset + vec2(padding, 3 * padding + barIconHeight + checkboxHeight)
        arrowUpRect.upper = arrowUpRect.lower + vec2(portraitWidth, arrowHeight)
        shipList.scrollUpButton = barContainer:createButton(arrowUpRect, "", "onScrollUpButtonPressed")
        shipList.scrollUpButton.icon = "data/textures/icons/arrow-up2.png"

        shipList.maxVisibleShips = math.floor((res.y - 3 * portraitHeight + 3 * padding - 2 * arrowHeight - (barIconHeight + padding + checkboxHeight)) / (portraitHeight + padding))

        arrowDownRect.lower = offset + vec2(padding, shipList.maxVisibleShips * (portraitHeight + padding) + 4 * padding + arrowHeight + barIconHeight + checkboxHeight)
        arrowDownRect.upper = arrowDownRect.lower + vec2(portraitWidth, arrowHeight)
        shipList.scrollDownButton = barContainer:createButton(arrowDownRect, "", "onScrollDownButtonPressed")
        shipList.scrollDownButton.icon = "data/textures/icons/arrow-down2.png"

        local shipFrameRect = Rect()
        shipFrameRect.lower = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
        shipFrameRect.upper = shipFrameRect.lower + vec2(portraitWidth + 2 * padding, 3 * padding + barIconHeight + checkboxHeight)
        shipList.frame = barContainer:createFrame(shipFrameRect)
        shipList.frame.catchAllMouseInput = true
        shipList.frame.layer = shipList.frame.layer - 1 -- the frame catches all input, make sure it is below other elements
        shipList.frame.backgroundColor = ColorARGB(0.5, 0.3, 0.3, 0.3)

        local shipListIconRect = Rect()
        shipListIconRect.lower = offset + vec2(portraitWidth / 2 - barIconHeight + padding, padding)
        shipListIconRect.upper = shipListIconRect.lower + vec2(barIconHeight * 2, barIconHeight)
        local shipListIcon = barContainer:createPicture(shipListIconRect, "data/textures/ui/fleet.png")
        shipListIcon.tooltip = "[CTRL A] Select all ships in the selected sector."%_t
        shipListIcon.isIcon = true

        local vsplit = UIVerticalMultiSplitter(shipFrameRect, 13, 10, 2)
        vsplit.marginTop = barIconHeight + padding

        stationsVisibleButton = barContainer:createButton(vsplit:partition(0), "", "onToggleStationsButtonPressed")
        stationsVisibleButton.hasFrame = false
        stationsVisibleButton.icon = "data/textures/icons/station.png"
        stationsVisibleButton.tooltip = "Show stations"%_t
        MapCommands.refreshButtonOverlays(stationsVisibleButton, shipList.stationsVisible)

        offscreenShipsVisibleButton = barContainer:createButton(vsplit:partition(1), "", "onToggleOffscreenButtonPressed")
        offscreenShipsVisibleButton.hasFrame = false
        offscreenShipsVisibleButton.icon = "data/textures/icons/eye.png"
        offscreenShipsVisibleButton.tooltip = "Show off-screen ships"%_t
        MapCommands.refreshButtonOverlays(offscreenShipsVisibleButton, shipList.offscreenShipsVisible)

        backgroundShipsVisibleButton = barContainer:createButton(vsplit:partition(2), "", "onToggleBGSButtonPressed")
        backgroundShipsVisibleButton.hasFrame = false
        backgroundShipsVisibleButton.icon = "data/textures/icons/background-simulation.png"
        backgroundShipsVisibleButton.tooltip = "Show ships on operations"%_t
        MapCommands.refreshButtonOverlays(backgroundShipsVisibleButton, shipList.backgroundShipsVisible)

        -- containers
        shipList.shipsContainer = GalaxyMap():createContainer()
        shipList.ordersContainer = GalaxyMap():createContainer()
        shipList.contextMenuContainer = GalaxyMap():createContainer()

        shipList.portraitContextMenu = shipList.contextMenuContainer:createContextMenu()

        -- buttons for orders
        orders = {}
        table.insert(orders, {tooltip = "Undo"%_t,              icon = "data/textures/icons/undo.png",              callback = "onUndoPressed",         type = OrderButtonType.Undo})
        table.insert(orders, {tooltip = "Patrol Sector"%_t,     icon = "data/textures/icons/back-forth.png",        callback = "onPatrolPressed",       type = OrderButtonType.Patrol})
        table.insert(orders, {tooltip = "Attack Enemies"%_t,    icon = "data/textures/icons/crossed-rifles.png",    callback = "onAggressivePressed",   type = OrderButtonType.Attack,      stationAllowed = true})
        table.insert(orders, {tooltip = "Repair"%_t,            icon = "data/textures/icons/health-normal.png",     callback = "onRepairPressed",       type = OrderButtonType.Repair})

        local sortedCommands = {}
        for type, _ in pairs(CommandFactory.getRegistry()) do
            table.insert(sortedCommands, type)
        end

        table.sort(sortedCommands, function(a, b) return CommandOrder[a] < CommandOrder[b] end)

        -- windows for special commands
        for _, type in pairs(sortedCommands) do
            local command
            if type ~= CommandType.Prototype then
                command = CommandFactory.makeCommand(type)
            end

            if not command or not command.buildUI then goto continue end

            command.mapCommands = MapCommands

            local windowButtonPressedCallback = command.type .. "_CommandButtonPressed"
            local areaSelectedCallback = command.type .. "_AreaSelected"
            local startPressedCallback = command.type .. "_StartButtonPressed"
            local changeAreaPressedCallback = command.type .. "_ChangeAreaButtonPressed"
            local onRecallPressedCallback = "onRecallPressed"
            local configChangedCallback = command.type .. "_ConfigChanged"

            local interface = {}
            interface.command = command
            interface.ui = command:buildUI(startPressedCallback, changeAreaPressedCallback, onRecallPressedCallback, configChangedCallback)
            interface.ui.current = {} -- this will be used to save the current area and config
            interface.ui.window:center()

            table.insert(orders, {tooltip = interface.ui.orderName, icon = interface.ui.icon, callback = windowButtonPressedCallback, type = command.type})

            -- function that is called when the round button of the command is pressed, after selecting the ship
            MapCommands[windowButtonPressedCallback] = function()
                -- hide all order windows
                for _, window in pairs(orderWindows) do
                    window:hide()
                end

                -- deselect additional ships as they would cause error messages when player starts command
                local selectedPortrait
                for _, portrait in pairs(shipList.selectedPortraits) do
                    if not selectedPortrait then
                        selectedPortrait = portrait
                    else
                        portrait.portrait.selected = false
                    end
                end

                if not selectedPortrait.portrait.available then
                    -- show read-only ui for the active command
                    local shipOwner = Galaxy():findFaction(selectedPortrait.owner)
                    local ret, data, descriptionArgs = shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "getCommandUIData", selectedPortrait.name)
                    if ret ~= 0 then return end

                    local entry = ShipDatabaseEntry(selectedPortrait.owner, selectedPortrait.name)

                    interface.ui:setActive(false, descriptionArgs)
                    interface.ui.commonUI:setAreaStats(data.area)
                    interface.ui.commonUI.escortUI:fillReadOnly(data.config.escorts)
                    interface.ui:displayPrediction(data.prediction, data.config, selectedPortrait.owner)

                    if valid(entry) then -- just to be sure. This should always work because the ship is in BGS
                        interface.ui:displayConfig(data.config, selectedPortrait.owner, entry)

                        local captain = entry:getCaptain()
                        if valid(captain) then
                            interface.ui.commonUI:setAssessment(captain, data.assessment, selectedPortrait.commandType)
                        end
                    end

                    interface.ui.window:show()
                    return
                end

                -- start area selection
                if selectedPortrait then
                    interface.ui.current.area = nil
                    areaSelection = nil

                    if command:isAreaFixed(selectedPortrait.owner, selectedPortrait.name) then
                        -- if the area is fixed, we can skip the whole area selection
                        local commandCallback = MapCommands[areaSelectedCallback]

                        -- the area that we're building here doesn't matter but we'll still do it for robustness' sake
                        local area = {}
                        area.lower = {}
                        area.upper = {}

                        local entry = ShipDatabaseEntry(selectedPortrait.owner, selectedPortrait.name)
                        local x, y = entry:getCoordinates()
                        local allowedSize = command:getAreaSize(selectedPortrait.owner, selectedPortrait.name)

                        local halfX = math.floor((allowedSize.x - 1) / 2)
                        local halfY = math.floor((allowedSize.y - 1) / 2)

                        area.lower.x = x - halfX
                        area.lower.y = y - halfY

                        area.upper.x = area.lower.x + allowedSize.x - 1 -- minus 1 because upper is inclusive
                        area.upper.y = area.lower.y + allowedSize.y - 1 -- minus 1 because upper is inclusive

                        commandCallback(area)
                        return
                    end

                    areaSelection = {}
                    areaSelection.craftName = selectedPortrait.name
                    areaSelection.craftOwner = selectedPortrait.owner

                    areaSelection.cancelling = false
                    areaSelection.commandCallback = MapCommands[areaSelectedCallback]
                    areaSelection.command = command

                    areaSelection.clampAreaToCraft = command:isShipRequiredInArea(selectedPortrait.owner, selectedPortrait.name)
                    local sizes = {command:getAreaSize(selectedPortrait.owner, selectedPortrait.name)}

                    local usedSize = MapCommands.nextUsedSize or 1
                    local size = sizes[usedSize]
                    MapCommands.nextUsedSize = nil

                    areaSelection.areaSize = vec2(size.x, size.y)
                else
                    areaSelection = nil
                end

            end

            -- function that is called after the area for the command was selected
            MapCommands[areaSelectedCallback] = function(area)
                local selected = MapCommands.getSelectedShips()
                local entry = ShipDatabaseEntry(selected.faction, selected.name)
                if not entry then return end

                interface.ui:clear(selected.faction, selected.name)
                interface.ui:setActive(true)

                currentBackgroundCommandWindow = interface.ui.window
                interface.ui.window:show()

                -- start the area analysis
                local x, y = entry:getCoordinates()

                interface.ui.current.area = nil
                MapCommands.startAreaAnalysis(selected.faction, selected.name, command.type, area)
            end

            -- function that is called when the "Start" button of the command is pressed
            MapCommands[startPressedCallback] = function()
                interface.ui.window:hide()

                local selected = MapCommands.getSelectedShips()
                local config = interface.ui:buildConfig()

                local shipOwner = Galaxy():findFaction(selected.faction)
                shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua",
                                     "startCommand",
                                     selected.name,
                                     interface.command.type,
                                     config)
            end

            -- function that is called when the "Change Area" button of the command is pressed
            MapCommands[changeAreaPressedCallback] = function()
                interface.ui.window:hide()

                MapCommands[windowButtonPressedCallback]()
            end

            MapCommands[onRecallPressedCallback] = MapCommands.onRecallPressed

            -- function that is called when the config of the command is changed
            MapCommands[configChangedCallback] = function()
                local selected = MapCommands.getSelectedShips()
                if not selected then return end

                -- don't handle configs of ships that are in BGS since their config can't change anyway
                -- usually map command UIs are refreshed periodically to keep UI up to date
                -- this is not necessary for non-available (ie. BGS) ships
                if not selected.available then return end

                if not interface.ui.current.area then return end

                local config = interface.ui:buildConfig()
                interface.ui:refreshPredictions(selected.faction, selected.name, interface.ui.current.area, config)
            end

            backgroundCommandInterfaces[type] = interface

            ::continue::
        end

        table.insert(orders, {tooltip = "Stop"%_t,              icon = "data/textures/icons/halt.png",              callback = "onStopPressed",         type = OrderButtonType.Stop,      stationAllowed = true})
        table.insert(orders, {tooltip = "Recall Ship"%_t,       icon = "data/textures/icons/arrow-left.png",        callback = "onRecallPressed",       type = OrderButtonType.Recall})

        shipList.orderButtons = {}
        for i, order in pairs(orders) do
            local button = shipList.ordersContainer:createRoundButton(Rect(), order.icon, order.callback)

            table.insert(shipList.orderButtons, button)
        end

        -- all windows
        for _, interface in pairs(backgroundCommandInterfaces) do
            table.insert(orderWindows, interface.ui.window)

            interface.ui.window.showCloseButton = true
            interface.ui.window.closeableWithEscape = true
            interface.ui.window.moveable = true
            interface.ui.window:hide()
        end


        -- input hints
        local size = vec2(1024, 16)
        local lower = vec2((res.x - size.x) * 0.5, res.y - size.y - 5)
        local rect = Rect(lower, lower + size)

        inputHints.container = GalaxyMap():createContainer(rect)
        inputHints.label = inputHints.container:createLabel(rect, "", 12)
        inputHints.label.outline = true
        inputHints.label.color = ColorRGB(0.6, 0.6, 0.6)
        inputHints.label:setBottomAligned()
        inputHints.label.fontSize = 12

        inputHints.texts = {}
        inputHints.texts[0] = "[WASD] Move Camera"%_t
        inputHints.texts[3] = "[CTRL] Select Multiple"%_t
        inputHints.texts[6] = "[MMB] Ping"%_t

        -- recall confirmation window
        MapCommands.buildRecallWindow()
        recallConfirmationWindow:hide()
    end
end