
function generateCaptain()
    -- seed either from remembered seed, or if old version of this mission is active only the client name as a fallback
    local seed = Seed(mission.data.arguments.client)
    local tier = mission.data.arguments.captain.tier
    local level = mission.data.arguments.captain.level
    local primaryClass = mission.data.arguments.captain.primaryClass
    local secondaryClass = mission.data.arguments.captain.secondaryClass
    local positiveTraits = mission.data.arguments.captain.positiveTraits
    local neutralTraits = mission.data.arguments.captain.neutralTraits
    local negativeTraits = mission.data.arguments.captain.negativeTraits
    local captain = CaptainGenerator(seed):generateWithTraits(tier, level, primaryClass, secondaryClass, positiveTraits, negativeTraits, neutralTraits)

    if captain.name ~= mission.data.arguments.captain.name then
        captain.name = mission.data.arguments.captain.name -- here for safety, shouldn't be needed
    end

    return captain
end