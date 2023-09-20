function CaptainUtility.getScoutCaptainCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        --return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        --return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        --return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        --return "10% faster travel time"%_t
    elseif class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Miner
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        --return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end 

function CaptainUtility.insertScoutCaptainPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
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
        if commandType == CommandType.Travel then
            CaptainUtility.insertTravelPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Scout then
            CaptainUtility.insertScoutPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Mine then
            CaptainUtility.insertMiningPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Salvage then
            CaptainUtility.insertSalvagingPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Refine then
            CaptainUtility.insertRefinePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Trade then
            CaptainUtility.insertTradePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Procure then
            CaptainUtility.insertProcurePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Sell then
            CaptainUtility.insertSellPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Supply then
            CaptainUtility.insertSupplyPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Expedition then
            CaptainUtility.insertExpeditionPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Maintenance then
            CaptainUtility.insertMaintenancePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Escort or commandType == CommandType.Prototype then
            -- nothing and that's okay
        -- custom command
        elseif commandType == CommandType.ScoutCaptain then
            CaptainUtility.insertScoutCaptainPerkSummaries(line, captain, perk, properties)
        else
            -- a new command has entered the arena
            eprint("CaptainUtility.makePerkSummaryLine: unknown command type:", commandType)
        end
    end

    return line
end