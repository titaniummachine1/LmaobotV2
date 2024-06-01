---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Utils = Lib.Utils
Common.TF2 = Common.Lib.TF2

Common.Math, Common.Conversion = Common.Utils.Math, Common.Utils.Conversion
Common.WPlayer, Common.PR = Common.TF2.WPlayer, Common.TF2.PlayerResource
Common.Helpers = Common.TF2.Helpers

Common.Notify = Lib.UI.Notify
Common.Log = Common.Utils.Logger.new("Navbot")
Common.Json = require("Lmaobot.Utils.Json")-- Require Json.lua directly

local G = require("Lmaobot.Utils.Globals")

function Common.Normalize(vec)
    local length = vec:Length()
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

-- Function to calculate Manhattan distance for horizontal check
function Common.horizontal_manhattan_distance(pos1, pos2)
    return math.abs(pos1.x - pos2.x) + math.abs(pos1.y - pos2.y)
end

function Common.LoadNavFile() -- Loads the nav file of the current map
    local mapFile = engine.GetMapName()
    local navFile = string.gsub(mapFile, ".bsp", ".nav")

    Navigation.LoadFile(navFile)
end

--- Adds a task to the current tasks table
--- @param taskKey string The key of the task to be added
function Common.AddCurrentTask(taskKey)
    local task = G.Tasks[taskKey]
    if task and not G.Current_Tasks[task] then
        G.Current_Tasks[task] = G.Tasks[taskKey]
    end
end

--- Removes a task from the current tasks table
--- @param taskKey string The key of the task to be removed
function Common.RemoveCurrentTask(taskKey)
    local task = G.Tasks[taskKey]
    if task then
        G.Current_Tasks[task] = nil
    end
end

--- Gets the highest priority task from the current tasks table
--- @return string The highest priority task key
function Common.GetHighestPriorityTask()
    local highestPriorityTask = nil
    local highestPriority = math.huge

    for task, priority in pairs(G.Current_Tasks) do
        if priority < highestPriority then
            highestPriority = priority
            highestPriorityTask = task
        end
    end

    for taskKey, value in pairs(G.Tasks) do
        if value == highestPriorityTask then
            return taskKey
        end
    end

    return nil
end



--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", "CD_Unload") -- unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", "CD_Unload", OnUnload) -- Register the "Unload" callback

return Common
