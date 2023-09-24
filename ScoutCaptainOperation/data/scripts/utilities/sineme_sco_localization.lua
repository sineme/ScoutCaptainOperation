Localization = {
    CaptainUtility = {
        ClassDescriptions = {
            Common = "Better at finding captains of the same class."%_t,
            Commodore = "-15% risk of being ambushed"%_t,
        },
        PerkSummaries = {
            Reckless = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t,
            Connected = "Finds ${var}% more candidates."%_t,
            Navigator = "${var}% faster"%_t,
            Stealthy = "${var}% lower risk of being ambushed"%_t,
            MarketExpert = "No effect on this command"%_t,
            Careful = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t,
            Disoriented = "${var}% slower"%_t,
            Gambler = "No effect on this command"%_t,
            Addict = "${var}% slower"%_t,
            Intimidating = "${var}% lower risk of being ambushed"%_t,
            Arrogant = "${var}% higher risk of being ambushed"%_t,
            Cunning = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t,
            Harmless = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t,
            Commoner = "${var1}% less combat prowess"%_t,
            Noble = "${var1}% more combat prowess"%_t,
            Lucky = "Finds up to ${var} items when executing the command"%_t,
            Unlucky = "${var}% chance of damaging the ship"%_t
        }
    },
    PromisingCaptainMission = {
        Brief = "A Promising Captain"%_t,
        Title = "A Promising Captain (Tier ${captain.tier})"%_t,
        Description = "${shipCaptain}, captain of ${shipName}, has informed you of a promising captain (Tier ${captain.tier}) in sector (${location.x}: ${location.y}). Check the stations in that sector if they are for hire or the bulletin boards if they are in trouble."%_t,
        Bulletin_Description = "Missing:\nName: ${displayName}\nProfession: ${class}\nAge: ${age}\nLast Known Location: (${x}:${y})\n\nIt's been a while since I've last had word from my good friend ${displayName}. Usually they check in with me regularly. I'm worried that something bad might have happened to them. The only clue I have to go on is their last message that they were on their way to sector (${x}:${y}). Please help me find my friend!\n\nMy friend is very capable, I'm sure they'll offer their loyalty to whomever rescues them!\n\n${client}"%_t
    }
}
return Localization
