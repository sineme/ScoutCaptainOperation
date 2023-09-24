local function removeTrait(trait, traits, positive, negative, neutral)
    removeItemsFromTable(traits, { trait })

    local opposites = opposingPerks[trait] or {}

    for _, opposite in pairs(opposites) do
        removeItemsFromTable(positive, { opposite, trait })
        removeItemsFromTable(negative, { opposite, trait })
        removeItemsFromTable(neutral, { opposite, trait })
    end
end

function CaptainGenerator:generateWithTraits(tier_in, level_in, primaryClass_in, secondaryClass_in, positiveTraits,
                                             negativeTraits, neutralTraits)
    if not positiveTraits and not negativeTraits and not neutralTraits then
        return generate(self, tier_in, level_in, primaryClass_in, secondaryClass_in)
    end

    positiveTraits = positiveTraits or {}
    negativeTraits = negativeTraits or {}
    neutralTraits = neutralTraits or {}

    -- check inputs
    if self:checkParametersFaulty(tier_in, level_in, primaryClass_in, secondaryClass_in) then
        return nil
    end

    -- inputs are fine => produce captain
    local captain = Captain()

    local language = Language(self.random:createSeed())
    captain.name = language:getName()

    if random():test(0.5) then
        captain.genderId = CaptainGenderId.Male
    else
        captain.genderId = CaptainGenderId.Female
    end

    -- set tier
    captain.tier = tier_in or self.random:getInt(0, 3)

    -- set class or classes, under consideration of given classes
    captain.primaryClass = primaryClass_in or 0
    captain.secondaryClass = secondaryClass_in or 0

    if (captain.tier > 0 and captain.primaryClass == 0)
        or (captain.tier == 3 and captain.secondaryClass == 0) then
        captain.primaryClass, captain.secondaryClass = self:determineCaptainClasses(self.random, captain.tier,
            primaryClass_in)
    end

    -- determine possible perks
    local positive, negative, neutral = self:getPossiblePerks()

    -- remove perks forbidden by primary class
    if captain.primaryClass ~= 0 then
        local positiveToRemove, negativeToRemove, neutralToRemove = self:getImpossiblePerksOfClass(captain.primaryClass)
        removeItemsFromTable(positive, positiveToRemove)
        removeItemsFromTable(negative, negativeToRemove)
        removeItemsFromTable(neutral, neutralToRemove)
        removeItemsFromTable(positiveTraits, positiveToRemove)
        removeItemsFromTable(negativeTraits, negativeToRemove)
        removeItemsFromTable(neutralTraits, neutralToRemove)
    end

    -- and for secondary class
    if captain.secondaryClass ~= 0 then
        local positiveToRemove, negativeToRemove, neutralToRemove = self:getImpossiblePerksOfClass(captain
            .secondaryClass)
        removeItemsFromTable(positive, positiveToRemove)
        removeItemsFromTable(negative, negativeToRemove)
        removeItemsFromTable(neutral, neutralToRemove)
        removeItemsFromTable(positiveTraits, positiveToRemove)
        removeItemsFromTable(negativeTraits, negativeToRemove)
        removeItemsFromTable(neutralTraits, neutralToRemove)
    end

    -- select perks
    local perks = {}
    local numPositivePerks, numNegativePerks, numNeutralPerks = self:getNumPerksFromTier(self.random, captain.tier)

    -- select requested perks
    for _, entry in pairs(positiveTraits) do
        if numPositivePerks > 0 then
            table.insert(perks, entry)

            removeTrait(entry, positive, positive, negative, neutral)

            numPositivePerks = numPositivePerks - 1
        else
            break
        end
    end

    for _, entry in pairs(negativeTraits) do
        if numNegativePerks > 0 then
            table.insert(perks, entry)

            removeTrait(entry, negative, positive, negative, neutral)

            numNegativePerks = numNegativePerks - 1
        else
            break
        end
    end

    for _, entry in pairs(neutralTraits) do
        if numNeutralPerks > 0 then
            table.insert(perks, entry)

            removeTrait(entry, neutral, positive, negative, neutral)

            numNeutralPerks = numNeutralPerks - 1
        else
            break
        end
    end

    -- select rest of perks
    local positivePerks = self:pickUniquePerks(positive, numPositivePerks, positive, negative, neutral)
    for _, entry in pairs(positivePerks) do
        table.insert(perks, entry)
    end

    local negativePerks = self:pickUniquePerks(negative, numNegativePerks, positive, negative, neutral)
    for _, entry in pairs(negativePerks) do
        table.insert(perks, entry)
    end

    local neutralPerks = self:pickUniquePerks(neutral, numNeutralPerks, positive, negative, neutral)
    for _, entry in pairs(neutralPerks) do
        table.insert(perks, entry)
    end

    captain:setPerks(perks)

    -- set level and experience
    captain.level = level_in or self:getLevelFromTier(self.random, captain.tier)
    captain.experience = 0
    CaptainUtility.setRequiredLevelUpExperience(captain)

    -- calculate salary from tier, classes and perks
    captain.salary = self:calculateSalary(captain)

    return captain
end

-- expose opposing perks to verify perk selection
-- in map command
function CaptainGenerator:getOpposingPerks()
    return opposingPerks
end
