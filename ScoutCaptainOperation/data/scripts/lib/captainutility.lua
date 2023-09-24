local sineme_SCO_Localization = include("utilities/sineme_SCO_Localization")

function CaptainUtility.getScoutCaptainTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.02
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.10
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0  -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0   -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase multiplier
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0      -- increase multiplier
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0     -- increase multiplier
    else
        return 0                                      -- fallback
    end
end

function CaptainUtility.getScoutCaptainTierProbabilityPerkImpact(captain, perk)
    local connectedImpacts = {}
    connectedImpacts[0] = 0.2
    connectedImpacts[1] = 0.4
    connectedImpacts[2] = 0.6
    connectedImpacts[3] = 0.8
    connectedImpacts[4] = 1.0
    connectedImpacts[5] = 1.2

    if perk == CaptainUtility.PerkType.Connected then
        return -connectedImpacts[captain.level] or 0 -- reduction multiplier
    else
        return 0                                     -- fallback
    end
end

function CaptainUtility.getScoutCaptainCommandCaptainClassDescription(class)
    local commonDescription = sineme_SCO_Localization.CaptainUtility.ClassDescriptions.Common
    if class == CaptainUtility.ClassType.Commodore then
        return commonDescription .. sineme_SCO_Localization.CaptainUtility.ClassDescriptions.Commodore
    elseif class == CaptainUtility.ClassType.Scavenger
        or class == CaptainUtility.ClassType.Miner
        or class == CaptainUtility.ClassType.Daredevil
        or class == CaptainUtility.ClassType.Merchant
        or class == CaptainUtility.ClassType.Smuggler
        or class == CaptainUtility.ClassType.Explorer
        or class == CaptainUtility.ClassType.Scientist
        or class == CaptainUtility.ClassType.Hunter then
        return commonDescription
    elseif class == CaptainUtility.ClassType.None then
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.insertScoutCaptainPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Reckless %
            {
                var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100,
                var2 = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100
            }
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Connected %
            { var = math.abs(CaptainUtility.getScoutCaptainTierProbabilityPerkImpact(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Navigator % { var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Stealthy %
            { var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.MarketExpert
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Careful %
            {
                var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100,
                var2 = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100
            }
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Disoriented % { var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Gambler
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Addict % { var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Intimidating %
            { var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Arrogant %
            { var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100 }
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Cunning %
            {
                var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100,
                var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100
            }
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Harmless %
            {
                var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100,
                var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100
            }
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Commoner %
            { var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100) }
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Noble %
            { var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100) }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Lucky %
            { var = CaptainUtility.getLuckyPerkAmount(captain, perk) }
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = sineme_SCO_Localization.CaptainUtility.PerkSummaries.Unlucky %
            { var = CaptainUtility.getUnluckyPerk(captain, perk) * 100 }
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
        or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

local CaptainUtility_getCaptainClassSummary = CaptainUtility.getCaptainClassSummary
function CaptainUtility.getCaptainClassSummary(class, commandType)
    if commandType then
        if commandType == CommandType.ScoutCaptain then
            return CaptainUtility.getScoutCaptainCommandCaptainClassDescription(class)
        else
            return CaptainUtility_getCaptainClassSummary(class, commandtype)
        end
    end
end

local CaptainUtility_makePerkSummaryLine = CaptainUtility.makePerkSummaryLine
function CaptainUtility.makePerkSummaryLine(captain, perk, commandType, properties)
    local lineHeight = 15
    local fontSize = 11
    local line = TooltipLine(lineHeight, fontSize)

    line.ltext = properties.summary
    line.icon = "data/textures/icons/nothing.png"
    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
    line.fontType = FontType.Normal

    if commandType then
        if commandType == CommandType.ScoutCaptain then
            CaptainUtility.insertScoutCaptainPerkSummaries(line, captain, perk, properties)
        else
            return CaptainUtility_makePerkSummaryLine(captain, perk, commandType, properties)
        end
    end

    return line
end
