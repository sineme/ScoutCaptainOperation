package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"
package.path = package.path .. ";data/scripts/player/missions/?.lua"
package.path = package.path .. ";data/scripts/utilities/?.lua"

include("utility")
include("bit32")

local CommandType = include("commandtype")
local SimulationUtility = include("simulationutility")
local CaptainUtility = include("captainutility")
local CaptainGenerator = include("captaingenerator")
local ScoutCaptainOperationUtility = include("scoutcaptainoperationutility")

-- why do I need an instance of the class for something that should be a static method
local positiveTraits, negativeTraits, neutralTraits = CaptainGenerator():getPossiblePerks()

local classProperties = CaptainUtility.ClassProperties()
local traitProperties = CaptainUtility.PerkProperties()

local maxNumNegativeTraits = 2
local maxNumNeutralTraits = 2
local maxNumPositiveTraits = 4

local baseNoCaptainChance = 0.65
local baseCaptainChance = 1 - baseNoCaptainChance
-- 100% increase between probabilities
local baseTier0Chance = baseCaptainChance * 8 / 15
local baseTier1Chance = baseCaptainChance * 4 / 15
local baseTier2Chance = baseCaptainChance * 2 / 15
local baseTier3Chance = baseCaptainChance * 1 / 15
-- 50% increase between probabilities
-- 27/65
-- 18/65
-- 12/65
--  8/65

local function fromCoordToXY(coord)
    local y = bit32.band(coord, 0x0000ffff)
    local x = bit32.band(coord, 0xffff0000)
    y = y - 0x7fff
    x = bit32.rshift(x, 16)
    x = x - 0x7fff
    return x, y
end

local function fromXYToCoord(x, y)
    y = y + 0x7fff
    x = x + 0x7fff
    x = bit32.lshift(x, 16)
    return x + y
end

local ScoutCaptainCommand = {}
ScoutCaptainCommand.__index = ScoutCaptainCommand
ScoutCaptainCommand.type = CommandType.ScoutCaptain

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    -- called very often on client
    -- called occasionally on server
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.ScoutCaptain,

        -- the ship that has the command
        shipName = ship,

        -- the area where the ship is doing its thing
        area = area,

        -- config that was given to the ship
        config = config,

        -- holds any data necessary to fulfill the command, that should be saved to database, eg. timers and so on
        -- this should only contain variables that can be saved to database (eg. returned in a secure()) call
        -- this will be automatically restored/secured
        data = {},

        -- will be set from external, only listed here for completeness' sake
        simulation = nil,
    }, ScoutCaptainCommand)

    command.data.runTime = 0
    command.data.yieldCounter = 0

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function ScoutCaptainCommand:addYield(message, money, resources, items) end
-- function ScoutCaptainCommand:finish() end
-- function ScoutCaptainCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function ScoutCaptainCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction
    self.data.duration = prediction.duration
    self.data.noCaptainChance = prediction.noCaptainChance
    self.data.tier0Chance = prediction.tier0Chance
    self.data.tier1Chance = prediction.tier1Chance
    self.data.tier2Chance = prediction.tier2Chance
    self.data.tier3Chance = prediction.tier3Chance
end

-- this is the regularly called function to update the time passing while the command is running
-- timestep is typically a longer period, such as a minute
-- this function should be as lightweight as possible. best practice is to
-- only do count downs here and do all calculations during area analysis and initialization
function ScoutCaptainCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep
    if self.data.runTime >= self.data.duration then
        self:finish()
        return
    end
end

-- executed before an area analysis involving this type of command starts
-- return a table of sectors here to start a special analysis of those sectors instead of a rect
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
-- note: See TravelCommand for an extensive example
function ScoutCaptainCommand:getAreaAnalysisSectors(results, meta)
    local sectorsToAnalyse = {}

    local player = Player(meta.callingPlayer)

    -- a captain can only be found in stations
    -- and the ship's captain doesn't know more than the player
    for x = meta.area.lower.x, meta.area.upper.x, 1 do
        for y = meta.area.lower.y, meta.area.upper.y, 1 do
            local sectorView = player:getKnownSector(x, y)
            if sectorView and sectorView.numStations > 0 then
                table.insert(sectorsToAnalyse, { x = x, y = y })
            end
        end
    end

    return sectorsToAnalyse
end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCaptainCommand:onAreaAnalysisStart(results, meta)
    results.totalNumRelevantStations = {}
    results.numRelevantStations = {}
    for _, classType in pairs(CaptainUtility.ClassType) do
        results.numRelevantStations[classType] = {}
        results.totalNumRelevantStations[classType] = 0
    end
end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCaptainCommand:onAreaAnalysisSector(results, meta, x, y)
    local sectorView = Player(meta.callingPlayer):getKnownSector(x, y)
    if not sectorView then
        -- should never happen, as the sector was known in getAreaAnalysisSectors
        eprint("Could not get sector view of (${x}, ${y})" % { x = x, y = y })
        return
    end
    -- add relevant stations for no specialization
    local coord = fromXYToCoord(x, y)
    local relevantStations = results.totalNumRelevantStations[CaptainUtility.ClassType.None]
    results.totalNumRelevantStations[CaptainUtility.ClassType.None] = relevantStations + sectorView.numStations
    results.numRelevantStations[CaptainUtility.ClassType.None] = results.numRelevantStations
        [CaptainUtility.ClassType.None]
    results.numRelevantStations[CaptainUtility.ClassType.None][coord] = sectorView.numStations

    local stations = { sectorView:getStationTitles() }
    for _, station in pairs(stations) do
        -- pass a fake station to determine the supported classType
        local classType = ScoutCaptainOperationUtility.getClassFromStation({ title = station.text })
        if classType then
            -- used to calculate the tier distribution of the captain
            results.totalNumRelevantStations[classType] = results.totalNumRelevantStations[classType] + 1
            -- used to calculate the travel time per sector
            -- used to chose the sector where the captain can be acquired
            results.numRelevantStations[classType] = results.numRelevantStations[classType]
            results.numRelevantStations[classType][coord] = (results.numRelevantStations[classType][coord] or 0) + 1
        end
    end
end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCaptainCommand:onAreaAnalysisFinished(results, meta)
end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
-- calculate and register the command for an attack if necessary here
function ScoutCaptainCommand:onStart()
    if self.data.prediction.attackLocation then
        local time = random():getFloat(0.1, 0.75) * self.config.duration
        local location = self.data.prediction.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({ x = x, y = y }, location.faction, time,
            "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, { self.shipName, x, y })
    end

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    entry:setStatusMessage("Scouting captains")
end

-- executed when the ship is being recalled by the player
function ScoutCaptainCommand:onRecall()
end

-- executed when the command is finished
function ScoutCaptainCommand:onFinish()
    -- determine tier
    local tiersDistribution = {}
    tiersDistribution[-1] = self.data.prediction.noCaptainChance
    tiersDistribution[0] = self.data.prediction.tier0Chance
    tiersDistribution[1] = self.data.prediction.tier1Chance
    tiersDistribution[2] = self.data.prediction.tier2Chance
    tiersDistribution[3] = self.data.prediction.tier3Chance

    local tier = selectByWeight(tiersDistribution)

    local faction = getParentFaction()
    local shipEntry = ShipDatabaseEntry(faction.index, self.shipName)
    local sx, sy = shipEntry:getCoordinates()
    local shipCaptain = shipEntry:getCaptain()
    if tier < 0 then
        faction:sendChatMessage(shipCaptain.displayName, ChatMessageType.Whisp,
            "Sorry, boss. I couldn't find a captain matching your description."%_t)
        faction:sendChatMessage(self.shipName, ChatMessageType.Information,
            "%1% has finished scouting captains and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName,
            sx, sy)
        return
    end

    local captain = {
        tier = tier,
        primaryClass = self.config.primaryClass,
        secondaryClass = self.config.secondaryClass,
        positiveTraits = self.config.positiveTraits,
        neutralTraits = self.config.neutralTraits,
        negativeTraits = self.config.negativeTraits
    }

    if tier >=3 then
        local numPrimaryClassStations = self.area.analysis.totalNumRelevantStations[captain.primaryClass]
        local numSecondaryClassStations = self.area.analysis.totalNumRelevantStations[captain.secondaryClass]
        local totalStations = numPrimaryClassStations + numSecondaryClassStations
        if random():test(numSecondaryClassStations / totalStations) then
            captain.primaryClass, captain.secondaryClass = captain.secondaryClass, captain.primaryClass
        end
    end
    local sector = selectByWeight(self.area.analysis.numRelevantStations[captain.primaryClass])

    local x, y = fromCoordToXY(sector)

    -- replace ClassType.None with nil
    if self.config.primaryClass == CaptainUtility.ClassType.None then
        self.config.primaryClass = nil
    end

    if self.config.secondaryClass == CaptainUtility.ClassType.None then
        self.config.secondaryClass = nil
    end

    faction:addScript("missions/promisingcaptainmission.lua", faction.index, self.shipName, x, y, captain)

    if tier >= 3 then
        faction:sendChatMessage(shipCaptain.displayName, ChatMessageType.Whisp,
            "I heard of a promising tier %1% captain in \\s(%2%:%3%). They went missing and someone is looking for them. Check the bulletin boards in that sector." %
            _T, captain.tier, x, y)
    else
        faction:sendChatMessage(shipCaptain.displayName, ChatMessageType.Whisp,
            "I found a promising tier %1% captain for hire in \\s(%2%:%3%)."%_T, captain.tier, x, y)
    end
    faction:sendChatMessage(self.shipName, ChatMessageType.Information,
        "%1% has finished scouting captains and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, sx,
        sy)
end

-- after this function was called, self.data will be read to be saved to database
function ScoutCaptainCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function ScoutCaptainCommand:onRestore()
end

-- this is called when the beforehand calculated pirate or faction attack happens
-- called after notification of player and after attack script is added to the ship database entry
-- but before the ship and its escort is recalled from background
-- note: attackerFaction is nil in case of a pirate attack
function ScoutCaptainCommand:onAttacked(attackerFaction, x, y)
end

function ScoutCaptainCommand:getDescriptionText()
    -- local totalRuntimeInMinutes = self.data.prediction.duration * 60
    local totalRuntime = self.data.prediction.duration
    local timeRemaining = totalRuntime - self.data.runTime
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "The ship is looking for talented captains.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T,
        { timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed }
end

-- returns the message that should be shown as the current ship action in the fleet overview
function ScoutCaptainCommand:getStatusMessage()
    return "Captain Scouting"%_T
end

-- returns the path to the icon that will be used in UI and on the galaxy map
function ScoutCaptainCommand:getIcon()
    return "data/textures/icons/scout-captain-command.png"
end

-- returns the size of the area where the command is currently running
-- this is used to visualize where the command is running at the moment
function ScoutCaptainCommand:getAreaBounds()
    return { lower = self.area.lower, upper = self.area.upper }
end

function ScoutCaptainCommand:getRecallError()
end

function ScoutCaptainCommand:HasTraitsImpossibleForClass(traitSet, classType, captainGenerator)
    local classTypeDisplayName = classProperties[classType].displayName

    local positive, negative, neutral = captainGenerator:getImpossiblePerksOfClass(classType)
    if positive then
        for _, impossibleTrait in pairs(positive) do
            if traitSet[impossibleTrait] then
                return "I won't find a ${classType} that is ${perkType}!"%_t %
                    { classType = classTypeDisplayName, perkType = traitProperties[impossibleTrait].displayName }
            end
        end
    end
    if negative then
        for _, impossibleTrait in pairs(negative) do
            if traitSet[impossibleTrait] then
                return "I won't find a ${classType} that is ${perkType}!"%_t %
                    { classType = classTypeDisplayName, perkType = traitProperties[impossibleTrait].displayName }
            end
        end
    end
    if neutral then
        for _, impossibleTrait in pairs(neutral) do
            if traitSet[impossibleTrait] then
                return "I won't find a ${classType} that is ${perkType}!"%_t %
                    { classType = classTypeDisplayName, perkType = traitProperties[impossibleTrait].displayName }
            end
        end
    end
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function ScoutCaptainCommand:getErrors(ownerIndex, shipName, area, config)
    if area.analysis.reachable == 0 then
        return "There are no sectors that I can reach!"%_t
    end

    -- check configured classes
    -- a captain can't have a secondary class without a primary class
    if (not config.primaryClass or config.primaryClass == 0) and (config.secondaryClass and config.secondaryClass ~= 0) then
        return "I won't find a captain without a primary class that has chosen to specialize in a second class!"%_t
    end
    -- the two classes of a captain must not be the same if they are not nil
    if (config.primaryClass and config.primaryClass ~= 0) and (config.secondaryClass and config.secondaryClass ~= 0) then
        if config.primaryClass == config.secondaryClass then
            return "I won't find a captain whose second specialization is the same as his primary class!"%_t
        end
    end

    -- create traitSet and assert uniqueness
    local traitSet = {}
    for _, trait in pairs(config.positiveTraits) do
        -- check uniqueness
        if traitSet[trait] then
            return "I won't find a captain that is ${perkType} multiple times!"%_t %
                { perkType = traitProperties[trait].displayName }
        else
            traitSet[trait] = true
        end
    end
    for _, trait in pairs(config.neutralTraits) do
        -- check uniqueness
        if traitSet[trait] then
            return "I won't find a captain that is ${perkType} multiple times!"%_t %
                { perkType = traitProperties[trait].displayName }
        else
            traitSet[trait] = true
        end
    end
    for _, trait in pairs(config.negativeTraits) do
        -- check uniqueness
        if traitSet[trait] then
            return "I won't find a captain that is ${perkType} multiple times!"%_t %
                { perkType = traitProperties[trait].displayName }
        else
            traitSet[trait] = true
        end
    end

    local captainGenerator = CaptainGenerator()
    -- check impossible traits based on class
    local hasTraitsImpossibleForClass = self:HasTraitsImpossibleForClass(traitSet, config.primaryClass, captainGenerator)
    if hasTraitsImpossibleForClass then
        return hasTraitsImpossibleForClass
    end
    hasTraitsImpossibleForClass = self:HasTraitsImpossibleForClass(traitSet, config.secondaryClass, captainGenerator)
    if hasTraitsImpossibleForClass then
        return hasTraitsImpossibleForClass
    end

    -- check contradicting traits
    local opposingTraits = captainGenerator:getOpposingPerks()
    for trait, _ in pairs(traitSet) do
        local opposingTraitsOfTrait = opposingTraits[trait] or {}
        for _, opposingTrait in pairs(opposingTraitsOfTrait) do
            if traitSet[opposingTrait] then
                return "I won't find a captain that is ${trait} and ${opposingTrait}!"%_t %
                    {
                        trait = traitProperties[trait].displayName,
                        opposingTrait = traitProperties[opposingTrait].displayName
                    }
            end
        end
    end

    -- if your command has a
    -- function MyCommand:isValidAreaSelection(ownerIndex, shipName, area, mouseCoordinates)
    -- defined, then make sure to re-check that in here as well!
    local areaSelectionIsValid = self:isValidAreaSelection(ownerIndex, shipName, area, config)
    if not areaSelectionIsValid then
        return "The designated area is invalid."%_t
    end

    local prediction = self:calculatePrediction(ownerIndex, shipName, area, config)

    if prediction.numRelevantStations <= 0 then
        return "There are no relevant stations in the designated area."%_t
    end

    if prediction.noCaptainChance >= 0.99 then
        return "There is no chance to find a captain with this description in the designated area."%_t
    end

    -- if there are no errors, just return
    return
end

-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:getAreaSize(ownerIndex, shipName)
    return { x = 21, y = 21 }
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

-- returns whether the command has a fixed area. if yes, the area will be calculated with the ship in the middle
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

-- note: this is only called on the client, not on the server.
-- note: this function definition is optional and can be omitted if it's not required
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:isValidAreaSelection(ownerIndex, shipName, area, mouseCoordinates)
    local player = Player(ownerIndex)

    -- a captain can only be found in stations
    -- and the ship's captain doesn't know more than the player
    -- so only allow if there is at least one
    -- known sector with stations
    for x = area.lower.x, area.upper.x, 1 do
        for y = area.lower.y, area.upper.y, 1 do
            local sectorView = player:getKnownSector(x, y)
            if sectorView and sectorView.numStations > 0 then
                return true
            end
        end
    end

    return false
end

-- scout captain command reuses the default area tooltip in MapCommands.onMapRenderAfterLayers()
function ScoutCaptainCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    if valid then
        return "Left-Click to select the target Area"%_t
    else
        return "No known stations in this area!"%_t
    end
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}

    -- value names here must match with values returned in ui:buildConfig() below
    values.primaryClass = { displayName = "Primary Class"%_t, defaultSelectedIndex = 0 }
    values.secondaryClass = { displayName = "Secondary Class"%_t, defaultSelectedIndex = 0 }
    values.negativeTraits = { displayName = "Negative Traits"%_t, defaultSelectedIndex = 0 }
    values.neutralTraits = { displayName = "Neutral Traits"%_t, defaultSelectedIndex = 0 }
    values.positiveTraits = { displayName = "Positive Traits"%_t, defaultSelectedIndex = 0 }
    -- number of cycles assuming a respawn rate of captains at stations?

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:getPredictableValues()
    local values = {}

    values.attackChance = { displayName = SimulationUtility.AttackChanceLabelCaption, value = 0.0 }
    values.duration = { displayName = "Duration"%_t, value = 0 }
    values.relevantStations = { displayName = "Relevant Stations"%_t, value = 1 }

    local tierDisplayNameFormat = "Tier ${tier}"%_t
    values.noCaptain = { displayName = "No Captain"%_t, value = 0.65 }
    values.tier0 = { displayName = tierDisplayNameFormat, value = 0.04375 }
    values.tier1 = { displayName = tierDisplayNameFormat, value = 0.175 }
    values.tier2 = { displayName = tierDisplayNameFormat, value = 0.0875 }
    values.tier3 = { displayName = tierDisplayNameFormat, value = 0.04375 }

    return values
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCaptainCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = {}

    local shipEntry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = shipEntry:getCaptain()
    --
    -- calculate number of relevant stations
    --
    local totalNumRelevantStations = 0
    if config.primaryClass and config.primaryClass ~= CaptainUtility.ClassType.None then
        -- None is skipped to avoid adding num of stations for None twice (once for primaryClass and secondaryClas)
        totalNumRelevantStations = area.analysis.totalNumRelevantStations[config.primaryClass] or 0
        if config.secondaryClass and config.secondaryClass ~= CaptainUtility.ClassType.None then
            local numRelevantStations = area.analysis.totalNumRelevantStations[config.secondaryClass] or 0
            totalNumRelevantStations = totalNumRelevantStations + numRelevantStations
        end
    else
        totalNumRelevantStations = area.analysis.totalNumRelevantStations[CaptainUtility.ClassType.None] or 0
    end
    results.numRelevantStations = totalNumRelevantStations
    -- used to determine the sector where the captain can be hired
    results.relevantSectorsPrimaryClass = area.analysis.numRelevantStations[config.primaryClass]
    results.relevantSectorsSecondaryClass = area.analysis.numRelevantStations[config.secondaryClass]

    --
    -- calculate duration prediction
    --
    local duration = 0

    -- possibly in the future calculate a jump route to include hyperspace jump range
    -- 1. calculate the interSectorTravelDuration by comparing hyperspace jump cooldown with hyperspace recharge
    local timeToTravelToNextSector = 0
    local jumpRange, canPassRifts, hyperspaceCooldown = shipEntry:getHyperspaceProperties()
    -- if hyperspace jump energy becomes available, compare cooldown with recharge time
    -- interSectorTravelDuration = max(hyperspaceCooldown, hyperspaceRequiredEnergy/shipEnergySurplus)
    timeToTravelToNextSector = hyperspaceCooldown
    local totalTravelTime = 0
    -- 2. calculate the innerSectorTravelDuration
    for _, numStations in pairs(area.analysis.numRelevantStations[config.primaryClass]) do
        -- can't get maxVelocity, etc. from ShipDatabaseEntry, so I assume 2 minutes per station
        -- local innerSectorTravelDuration = averageDistance / maxVelocity * numStations
        local timeToTravelBetweenAllStations = 2 * 60 * numStations
        totalTravelTime = totalTravelTime + math.max(timeToTravelToNextSector, timeToTravelBetweenAllStations)
    end
    -- 3. apply reckless, careful, navigator, disoriented
    local totalTravelTimePerkImpactMultiplier = 1
    -- Navigator impact
    if captain:hasPerk(CaptainUtility.PerkType.Navigator) then
        totalTravelTimePerkImpactMultiplier = totalTravelTimePerkImpactMultiplier +
            CaptainUtility.getScoutCaptainTimePerkImpact(captain, CaptainUtility.PerkType.Navigator)
    end
    -- Reckless impact
    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then
        totalTravelTimePerkImpactMultiplier = totalTravelTimePerkImpactMultiplier +
            CaptainUtility.getScoutCaptainTimePerkImpact(captain, CaptainUtility.PerkType.Reckless)
    end
    -- Disoriented impact
    if captain:hasPerk(CaptainUtility.PerkType.Disoriented) then
        totalTravelTimePerkImpactMultiplier = totalTravelTimePerkImpactMultiplier +
            CaptainUtility.getScoutCaptainTimePerkImpact(captain, CaptainUtility.PerkType.Disoriented)
    end
    -- Addict impact
    if captain:hasPerk(CaptainUtility.PerkType.Addict) then
        totalTravelTimePerkImpactMultiplier = totalTravelTimePerkImpactMultiplier +
            CaptainUtility.getScoutCaptainTimePerkImpact(captain, CaptainUtility.PerkType.Addict)
    end
    -- Careful impact
    if captain:hasPerk(CaptainUtility.PerkType.Careful) then
        totalTravelTimePerkImpactMultiplier = totalTravelTimePerkImpactMultiplier +
            CaptainUtility.getScoutCaptainTimePerkImpact(captain, CaptainUtility.PerkType.Careful)
    end

    -- 4. minimum trip time is 20 minutes
    duration = math.max(totalTravelTimePerkImpactMultiplier * totalTravelTime, 20 * 60)

    -- 5. simulate the time it takes to find the right one out of the available ones
    local timeToSortThroughCaptains = 3600 * #config.positiveTraits + 1800 * #config.neutralTraits +
        900 * #config.negativeTraits

    duration = duration + timeToSortThroughCaptains

    -- if the captain should cycle the stations to increase the odds of finding a good captain
    -- duration = duration * cycles

    --
    -- calculate captain prediction
    --
    results.noCaptainChance = 0
    results.tier0Chance = 0
    results.tier1Chance = 0
    results.tier2Chance = 0
    results.tier3Chance = 0
    if totalNumRelevantStations > 0 then
        if captain:hasPerk(CaptainUtility.PerkType.Connected) then
            totalNumRelevantStations = totalNumRelevantStations +
            totalNumRelevantStations *
            CaptainUtility.getScoutCaptainTierProbabilityPerkImpact(captain, CaptainUtility.PerkType.Connected)
        end
        if captain:hasClass(config.primaryClass) then
            totalNumRelevantStations = totalNumRelevantStations * 1.15
        end
        if captain:hasClass(config.secondaryClassClass) then
            totalNumRelevantStations = totalNumRelevantStations * 1.15
        end

        local noCaptainChance = baseNoCaptainChance ^ totalNumRelevantStations
        local tier0OrLowerChance = (baseTier0Chance + baseNoCaptainChance) ^ totalNumRelevantStations
        local tier1OrLowerChance = (baseTier1Chance + baseTier0Chance + baseNoCaptainChance) ^ totalNumRelevantStations
        local tier2OrLowerChance = (baseTier2Chance + baseTier1Chance + baseTier0Chance + baseNoCaptainChance) ^
            totalNumRelevantStations

        results.noCaptainChance = noCaptainChance
        results.tier0Chance = tier0OrLowerChance - noCaptainChance
        results.tier1Chance = tier1OrLowerChance - tier0OrLowerChance
        results.tier2Chance = tier2OrLowerChance - tier1OrLowerChance
        results.tier3Chance = 1 - tier2OrLowerChance

        --
        -- the following comment is intended for the case that disabling tiers is implemented
        --
        -- normalize probabilities and use normalization factor on duration
        -- local normalizationFactor = results.noCaptainChance + results.tier0Chance + results.tier1Chance + results.tier2Chance + results.tier3Chance
        -- normalizationFactor = 1 / normalizationFactor
        -- duration = normalizationFactor * duration
    else
        results.noCaptainChance = 1
    end

    results.duration = duration

    -- calculate attack chance prediction
    results.attackChance, results.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName,
        area, config.escorts, duration / 3600)

    return results
end

function ScoutCaptainCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    -- please don't just copy this function. It's specific to the mine command.
    -- use it as a guidance, but don't just use the same sentences etc.

    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "There are no reachable sectors in this area!"%_t end

    local noCaptainChance = prediction.noCaptainChance or 0
    local attackChance = prediction.attackChance
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local noCaptainProbabilityLines = {}
    if noCaptainChance >= 0.75 then
        table.insert(noCaptainProbabilityLines, "It's unlikely to find such a captain here."%_t)
    elseif noCaptainChance >= 0.45 then
        table.insert(noCaptainProbabilityLines, "It's hit-or-miss to find such a captain here."%_t)
    elseif noCaptainChance >= 0.05 then
        table.insert(noCaptainProbabilityLines, "It's likely to find such a captain here."%_t)
    elseif noCaptainChance > 0.0 then
        table.insert(noCaptainProbabilityLines, "It's almost certain to find such a captain here."%_t)
    else
        table.insert(noCaptainProbabilityLines, "It's certain to find such a captain here."%_t)
    end

    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, noCaptainProbabilityLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

function ScoutCaptainCommand:buildConfigUI(window, rect, configValues, configChangedCallback)
    local ui = {}

    -- padding: 25, margin: 0
    local vlist = UIVerticalLister(rect, 25, 0)

    -- class selection
    -- padding: 10, margin: 0, ratio:0.5
    local vsplitPrimarySecondaryClass = UIVerticalSplitter(vlist:nextRect(25), 10, 0, 0.5)

    -- primary class selection
    local vsplitPrimaryClass = UIVerticalSplitter(vsplitPrimarySecondaryClass.left, 10, 0, 0.5)
    window:createLabel(vsplitPrimaryClass.left, configValues.primaryClass.displayName, 13)
    ui.primaryClassComboBox = window:createValueComboBox(vsplitPrimaryClass.right, configChangedCallback)

    -- secondary class selection
    local vsplitSecondaryClass = UIVerticalSplitter(vsplitPrimarySecondaryClass.right, 10, 0, 0.5)
    window:createLabel(vsplitSecondaryClass.left, configValues.secondaryClass.displayName, 13)
    ui.secondaryClassComboBox = window:createValueComboBox(vsplitSecondaryClass.right, configChangedCallback)

    -- initialize the class combo boxes with values
    -- sort classes first
    local function classComparer(a, b) return a < b end
    local sortedClasses = {}
    for className, classType in pairs(CaptainUtility.ClassType) do
        table.insert(sortedClasses, classType)
    end
    table.sort(sortedClasses, classComparer)

    for index, class in pairs(sortedClasses) do
        local classProperty = classProperties[class]

        ui.primaryClassComboBox:addEntry(class, classProperty.displayName)
        ui.primaryClassComboBox:setEntryTooltip(index - 1, classProperty.description)

        ui.secondaryClassComboBox:addEntry(class, classProperty.displayName)
        ui.secondaryClassComboBox:setEntryTooltip(index - 1, classProperty.description)
    end

    -- traits selection
    local traitsSelectionRect = vlist:nextRect(60)
    local vsplitTraits = UIVerticalMultiSplitter(traitsSelectionRect, 10, 0, 2)

    -- negative traits
    local vlistNegativeTraits = UIVerticalLister(vsplitTraits:partition(0), 10, 0)
    window:createLabel(vlistNegativeTraits:nextRect(20), configValues.negativeTraits.displayName, 13)
    ui.negativeTraitsComboBoxes = {}
    for i = 1, maxNumNegativeTraits do
        local negativeTraitComboBox = window:createValueComboBox(vlistNegativeTraits:nextRect(30), configChangedCallback)
        negativeTraitComboBox:addEntry(nil, "")
        for negativeTraitIndex, negativeTrait in pairs(negativeTraits) do
            local negativeTraitProperty = traitProperties[negativeTrait]
            negativeTraitComboBox:addEntry(negativeTrait, negativeTraitProperty.displayName)
            negativeTraitComboBox:setEntryTooltip(negativeTraitIndex, negativeTraitProperty.description)
        end
        ui.negativeTraitsComboBoxes[i] = negativeTraitComboBox
    end

    -- neutral traits
    local vlistNeutralTraits = UIVerticalLister(vsplitTraits:partition(1), 10, 0)
    window:createLabel(vlistNeutralTraits:nextRect(20), configValues.neutralTraits.displayName, 13)
    ui.neutralTraitsComboBoxes = {}
    for i = 1, maxNumNeutralTraits do
        local neutralTraitComboBox = window:createValueComboBox(vlistNeutralTraits:nextRect(30), configChangedCallback)
        neutralTraitComboBox:addEntry(nil, "")
        for neutralTraitIndex, neutralTrait in pairs(neutralTraits) do
            local neutralTraitProperty = traitProperties[neutralTrait]
            neutralTraitComboBox:addEntry(neutralTrait, neutralTraitProperty.displayName)
            neutralTraitComboBox:setEntryTooltip(neutralTraitIndex, neutralTraitProperty.description)
        end
        ui.neutralTraitsComboBoxes[i] = neutralTraitComboBox
    end

    -- positive traits
    local vlistPositiveTraits = UIVerticalLister(vsplitTraits:partition(2), 10, 0)
    window:createLabel(vlistPositiveTraits:nextRect(20), configValues.positiveTraits.displayName, 13)
    ui.positiveTraitsComboBoxes = {}
    for i = 1, maxNumPositiveTraits do
        local positiveTraitComboBox = window:createValueComboBox(vlistPositiveTraits:nextRect(30), configChangedCallback)
        positiveTraitComboBox:addEntry(nil, "")
        for positiveTraitIndex, positiveTrait in pairs(positiveTraits) do
            local positiveTraitProperty = traitProperties[positiveTrait]
            positiveTraitComboBox:addEntry(positiveTrait, positiveTraitProperty.displayName)
            positiveTraitComboBox:setEntryTooltip(positiveTraitIndex, positiveTraitProperty.description)
        end
        ui.positiveTraitsComboBoxes[i] = positiveTraitComboBox
    end

    return ui
end

function ScoutCaptainCommand:buildPredictionUI(window, rect, predictableValues, commonUI)
    local ui = {}

    local vsplitNamesValues = UIVerticalSplitter(rect, 10, 0, 0.5)
    local vlistDisplayNames = UIVerticalLister(vsplitNamesValues.left, 10, 0)
    local vlistValues = UIVerticalLister(vsplitNamesValues.right, 10, 0)

    -- display name labels
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.attackChance.displayName .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.duration.displayName .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.relevantStations.displayName .. ":", 12)
    vlistDisplayNames:nextRect(15)
    window:createLabel(vlistDisplayNames:nextRect(20), "Captain"%_t .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.noCaptain.displayName .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.tier0.displayName % { tier = 0 } .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.tier1.displayName % { tier = 1 } .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.tier2.displayName % { tier = 2 } .. ":", 12)
    window:createLabel(vlistDisplayNames:nextRect(15), predictableValues.tier3.displayName % { tier = 3 } .. ":", 12)

    -- value labels
    commonUI.attackChanceLabel = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.durationLabel = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.relevantStationsLabel = window:createLabel(vlistValues:nextRect(15), "", 12)
    vlistValues:nextRect(15)
    vlistValues:nextRect(20)
    ui.noCaptainLabel = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.tier0Label = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.tier1Label = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.tier2Label = window:createLabel(vlistValues:nextRect(15), "", 12)
    ui.tier3Label = window:createLabel(vlistValues:nextRect(15), "", 12)

    return ui
end

local function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCaptainCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback,
                                     configChangedCallback)
    local ui = {}
    ui.orderName = "Scout Captain"%_t
    ui.icon = ScoutCaptainCommand:getIcon()

    local size = vec2(700, 820)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Scout Captain /* as in: to scout a talent, talent scouting, headhunting*/"%_t

    local settings = { configHeight = 225, changeAreaButton = true }
    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback,
        recallPressedCallback, configChangedCallback, settings)

    -- configurable values
    local configValues = self:getConfigurableValues()
    ui.configUI = self:buildConfigUI(ui.window, ui.commonUI.configRect, configValues, configChangedCallback)

    -- yields & issues
    local predictableValues = self:getPredictableValues()
    ui.predictionUI = self:buildPredictionUI(ui.window, ui.commonUI.predictionRect, predictableValues, ui.commonUI)

    ui.clear = function (self, ownerIndex, shipName)
        self.commonUI:clear()

        self.commonUI.attackChanceLabel.caption = ""
        self.predictionUI.durationLabel.caption = ""
        self.predictionUI.relevantStationsLabel.caption = ""
        self.predictionUI.noCaptainLabel.caption = ""
        self.predictionUI.tier0Label.caption = ""
        self.predictionUI.tier1Label.caption = ""
        self.predictionUI.tier2Label.caption = ""
        self.predictionUI.tier3Label.caption = ""
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function (self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local configValues = ScoutCaptainCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            self.configUI.primaryClassComboBox:setSelectedIndexNoCallback(configValues.primaryClass.defaultSelectedIndex)
            self.configUI.secondaryClassComboBox:setSelectedIndexNoCallback(configValues.secondaryClass
                .defaultSelectedIndex)
            for _, traitComboBox in pairs(self.configUI.negativeTraitsComboBoxes) do
                traitComboBox:setSelectedIndexNoCallback(configValues.negativeTraits.defaultSelectedIndex)
            end
            for _, traitComboBox in pairs(self.configUI.neutralTraitsComboBoxes) do
                traitComboBox:setSelectedIndexNoCallback(configValues.neutralTraits.defaultSelectedIndex)
            end
            for _, traitComboBox in pairs(self.configUI.positiveTraitsComboBoxes) do
                traitComboBox:setSelectedIndexNoCallback(configValues.positiveTraits.defaultSelectedIndex)
            end
            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function (self, ownerIndex, shipName, area, config)
        local prediction = ScoutCaptainCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)
        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, ScoutCaptainCommand, prediction)
    end

    ui.displayPrediction = function (self, prediction, config, ownerIndex)
        self.commonUI:setAttackChance(prediction.attackChance)
        local date = os.date("!*t", prediction.duration)
        self.predictionUI.durationLabel.caption = string.format("%s h %s min", date.hour, date.min)
        self.predictionUI.relevantStationsLabel.caption = string.format("%s", prediction.numRelevantStations)
        self.predictionUI.noCaptainLabel.caption = string.format("%.3f", prediction.noCaptainChance * 100):gsub("%.?0+$",
            "") .. "%"
        self.predictionUI.tier0Label.caption = string.format("%.3f", prediction.tier0Chance * 100):gsub("%.?0+$", "") ..
            "%"
        self.predictionUI.tier1Label.caption = string.format("%.3f", prediction.tier1Chance * 100):gsub("%.?0+$", "") ..
            "%"
        self.predictionUI.tier2Label.caption = string.format("%.3f", prediction.tier2Chance * 100):gsub("%.?0+$", "") ..
            "%"
        self.predictionUI.tier3Label.caption = string.format("%.3f", prediction.tier3Chance * 100):gsub("%.?0+$", "") ..
            "%"
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function (self)
        local config = {}

        config.primaryClass = nil
        config.secondaryClass = nil
        config.negativeTraits = {}
        config.neutralTraits = {}
        config.positiveTraits = {}

        config.primaryClass = self.configUI.primaryClassComboBox.selectedValue
        config.secondaryClass = self.configUI.secondaryClassComboBox.selectedValue

        for i = 1, maxNumNegativeTraits do
            local negativeTrait = self.configUI.negativeTraitsComboBoxes[i].selectedValue
            if negativeTrait then
                config.negativeTraits[i] = negativeTrait
            end
        end

        for i = 1, maxNumNeutralTraits do
            local neutralTrait = self.configUI.neutralTraitsComboBoxes[i].selectedValue
            if neutralTrait then
                config.neutralTraits[i] = neutralTrait
            end
        end

        for i = 1, maxNumPositiveTraits do
            local positiveTrait = self.configUI.positiveTraitsComboBoxes[i].selectedValue
            if positiveTrait then
                config.positiveTraits[i] = positiveTrait
            end
        end

        return config
    end

    -- optional; called whenever the command window was closed while the map is still visible
    ui.onWindowClosed = function (self) end

    ui.setActive = function (self, active, description)
        self.commonUI:setActive(active, description)

        self.configUI.primaryClassComboBox.active = active
        self.configUI.secondaryClassComboBox.active = active
        for _, comboBox in pairs(self.configUI.positiveTraitsComboBoxes) do comboBox.active = active end
        for _, comboBox in pairs(self.configUI.neutralTraitsComboBoxes) do comboBox.active = active end
        for _, comboBox in pairs(self.configUI.negativeTraitsComboBoxes) do comboBox.active = active end
    end

    ui.displayConfig = function (self, config, ownerIndex)
        ui.configUI.primaryClassComboBox:setSelectedIndexNoCallback(config.primaryClass)
        ui.configUI.secondaryClassComboBox:setSelectedIndexNoCallback(config.secondaryClass)

        -- TODO: display traits
        for i, trait in pairs(config.positiveTraits) do
            traitIndex = indexOf(positiveTraits, trait)
            ui.configUI.positiveTraitsComboBoxes[i]:setSelectedIndexNoCallback(traitIndex)
        end

        for i, trait in pairs(config.neutralTraits) do
            traitIndex = indexOf(neutralTraits, trait)
            ui.configUI.neutralTraitsComboBoxes[i]:setSelectedIndexNoCallback(traitIndex)
        end

        for i, trait in pairs(config.negativeTraits) do
            traitIndex = indexOf(negativeTraits, trait)
            ui.configUI.negativeTraitsComboBoxes[i]:setSelectedIndexNoCallback(traitIndex)
        end
    end

    return ui
end

return setmetatable({ new = new }, { __call = function (_, ...) return new(...) end })
