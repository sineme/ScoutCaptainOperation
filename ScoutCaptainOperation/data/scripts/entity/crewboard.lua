function CrewBoard.setAvailableCaptain(captain)
    if not captain then return end

    availableCaptain = captain

    CrewBoard.sync()
end
