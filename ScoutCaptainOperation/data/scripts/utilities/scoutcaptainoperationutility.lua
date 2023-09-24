package.path = package.path .. ";data/scripts/utilities/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local CaptainUtility = include("captainutility")

local classProperties = CaptainUtility.ClassProperties()
local traitProperties = CaptainUtility.PerkProperties()

local ScoutCaptainOperationUtility = {}

local scriptPath = "data/scripts/player/missions/receivecaptainmission.lua"

-- I am crying inside that I have to copy this method from receivecaptainmission.lua
-- to prevent global environment pollution
function ScoutCaptainOperationUtility.getClassFromStation(station)
    local title = station.title
    if title == "Smuggler's Market" or title == "Smuggler Hideout" then
        return CaptainUtility.ClassType.Smuggler
    end

    if title == "Military Outpost" then
        return CaptainUtility.ClassType.Commodore
    end

    if title == "Trading Post" then
        return CaptainUtility.ClassType.Merchant
    end

    if string.match(title, " Mine") then
        return CaptainUtility.ClassType.Miner
    end

    if title == "Scrapyard" then
        return CaptainUtility.ClassType.Scavenger
    end

    if title == "Research Station" then
        return CaptainUtility.ClassType.Explorer
    end

    if title == "Resistance Outpost" then
        return CaptainUtility.ClassType.Hunter
    end

    if title == "Rift Research Center" then
        return CaptainUtility.ClassType.Scientist
    end

    if title == "Casino" or title == "Habitat" then
        return CaptainUtility.ClassType.Daredevil
    end

    return nil
end

function ScoutCaptainOperationUtility.printCaptain(captain)
    print("Name: " .. captain.name)
    print("Tier: " .. captain.tier)
    print("Level: " .. captain.level)
    print("Hiring Price: " .. captain.hiringPrice)
    print("Salary: " .. captain.salary)
    print("Primary Class: " .. classProperties[captain.primaryClass].displayName)
    print("Secondary Class: " .. classProperties[captain.secondaryClass].displayName)
    print("Perks: ")
    local perks = { captain:getPerks() }
    for _, perk in pairs(perks) do
        print("\t " .. traitProperties[perk].displayName)
    end
end

function ScoutCaptainOperationUtility.printCaptainConfig(captainConfig)
    print("Tier: " .. captainConfig.tier)
    print("Primary Class: " .. classProperties[captainConfig.primaryClass].displayName)
    print("Secondary Class: " .. classProperties[captainConfig.secondaryClass].displayName)
    print("Perks: ")
    for _, trait in pairs(captainConfig.positiveTraits) do
        print("\t " .. traitProperties[trait].displayName)
    end
    for _, trait in pairs(captainConfig.neutralTraits) do
        print("\t " .. traitProperties[trait].displayName)
    end
    for _, trait in pairs(captainConfig.negativeTraits) do
        print("\t " .. traitProperties[trait].displayName)
    end
end

return ScoutCaptainOperationUtility
