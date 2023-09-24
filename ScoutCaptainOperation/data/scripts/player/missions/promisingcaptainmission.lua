package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("mission")

local sineme_SCO_Localization = include("utilities/sineme_SCO_Localization")
local ScoutCaptainOperationUtility = include("utilities/scoutcaptainoperationutility")
local CaptainGenerator = include("captaingenerator")

missionData.brief = sineme_SCO_Localization.PromisingCaptainMission.Brief
missionData.title = sineme_SCO_Localization.PromisingCaptainMission.Title
missionData.description = sineme_SCO_Localization.PromisingCaptainMission.Description


-- 2h time limit
missionData.timeLimit = 2 * 3600

function initialize(factionIndex, shipName, x, y, captain)
    initMissionCallbacks()
    if onClient() then
        sync()
        return
    end
    printTable({
        initialize = {
            factionIndex = factionIndex,
            shipName = shipName,
            x = x,
            y = y,
            captain = captain
        }
    })

    -- if it's not being initialized from outside, skip initialization
    -- the script will be restored via restore()
    if _restoring or not factionIndex then return end

    local shipEntry = ShipDatabaseEntry(factionIndex, shipName)
    local shipCaptain = shipEntry:getCaptain()

    missionData.fulfilled = 0
    missionData.justStarted = true
    missionData.location = { x = x, y = y }
    missionData.captain = captain
    missionData.shipName = shipName
    missionData.shipCaptain = shipCaptain.displayName

    local player = Player()
    local px, py = player:getSectorCoordinates()
    if px == x and py == y then
        onTargetLocationEntered(x, y)
    end
end

function onTargetLocationEntered(x, y)
    local sector = Sector()

    -- select station
    local stations = { sector:getEntitiesByType(EntityType.Station) }
    local targetStation = nil
    if missionData.captain.tier == 0 then
        local station = randomEntry(stations)
        targetStation = station
    else
        for _, station in pairs(stations) do
            local class = ScoutCaptainOperationUtility.getClassFromStation(station)
            if class == missionData.captain.primaryClass then
                targetStation = station
                break
            end
        end
    end

    if not targetStation then
        eprint("sineme.ScoutCaptainOperation.scoutcaptainevent.lua: No valid target station in this sector.")
        terminate()
        return
    end

    if missionData.captain.tier < 3 then
        -- create the captain and make him hireable at the station
        local captain = CaptainGenerator():generateWithTraits(
            missionData.captain.tier,
            nil,
            missionData.captain.primaryClass,
            nil,
            missionData.captain.positiveTraits,
            missionData.captain.negativeTraits,
            missionData.captain.neutralTraits)

        local response = targetStation:invokeFunction(
            "crewboard.lua",
            "setAvailableCaptain",
            captain)

        if response ~= 0 then
            if not response then
                response = "no response"
            end
            eprint(
                "sineme.ScoutCaptainOperation.scoutcaptainevent.lua: Failed to set the available captain of the crewboard. Response code ${responseCode}" %
                { responseCode = response })
        end
    else
        -- create a "A Lost Friend"-Mission at the station
        local scriptPath = "data/scripts/player/missions/receivecaptainmission.lua"
        local ok, bulletin = run(scriptPath, "getBulletin", targetStation)

        if ok == 0 and bulletin then
            -- the captain is rewarding enough
            bulletin.formatArguments.reward = createMonetaryString(0)
            bulletin.description = sineme_SCO_Localization.PromisingCaptainMission.Bulletin_Description
            bulletin.arguments[1].reward = 0
            -- tier is set to 3 due to the nature of the mission
            -- primary class is determined by type of station
            bulletin.arguments[1].captain.secondaryClass = missionData.captain.secondaryClass
            bulletin.arguments[1].captain.positiveTraits = missionData.captain.positiveTraits
            bulletin.arguments[1].captain.neutralTraits = missionData.captain.neutralTraits
            bulletin.arguments[1].captain.negativeTraits = missionData.captain.negativeTraits

            -- add bulletin
            targetStation:invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
            targetStation:invokeFunction("bulletinboard", "postBulletin", bulletin)
        else
            eprint(
                "sineme.ScoutCaptainOperation.scoutcaptainevent.lua: Failed to get the bulletin board. Response code ${code}" %
                { code = ok })
        end
    end

    -- we do not want to accomplish this mission, so we terminate it here
    -- there are no usable callbacks to check if the captain was hired
    -- or if the "A Lost Friend"-mission was taken
    terminate()
end
