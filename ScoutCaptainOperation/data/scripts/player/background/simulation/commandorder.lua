package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include("commandtype")

local CommandOrder = {}
CommandOrder[CommandType.Prototype] = 1
CommandOrder[CommandType.Travel] = 2
CommandOrder[CommandType.Scout] = 3
CommandOrder[CommandType.Mine] = 4
CommandOrder[CommandType.Salvage] = 5
CommandOrder[CommandType.Refine] = 6
CommandOrder[CommandType.Procure] = 7
CommandOrder[CommandType.Sell] = 8
CommandOrder[CommandType.Trade] = 9
CommandOrder[CommandType.Supply] = 10
CommandOrder[CommandType.Expedition] = 11
CommandOrder[CommandType.Maintenance] = 12
CommandOrder[CommandType.Escort] = 13
CommandOrder[CommandType.ScoutCaptain] = 14

return CommandOrder