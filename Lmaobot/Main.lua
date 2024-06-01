--[[ Annotations ]]
---@alias NavConnection { count: integer, connections: integer[] }
---@alias NavNode { id: integer, x: number, y: number, z: number, c: { [1]: NavConnection, [2]: NavConnection, [3]: NavConnection, [4]: NavConnection } }

--[[ Imports ]]
local Common = require("Lmaobot.Utils.Common")
local G = require("Lmaobot.Utils.Globals")
local Navigation = require("Lmaobot.Utils.Navigation")
local WorkManager = require("Lmaobot.WorkManager")
local Lib = Common.Lib

-- Unload package for debugging
Lib.Utils.UnloadPackages("Lmaobot")

local Notify, FS, Fonts, Commands, Math, WPlayer = Lib.UI.Notify, Lib.Utils.FileSystem, Lib.UI.Fonts, Lib.Utils.Commands, Lib.Utils.Math, Lib.TF2.WPlayer
local Log = Lib.Utils.Logger.new("Lmaobot")
Log.Level = 0

--[[ Variables ]]
local Menu = G.Menu

--[[ Functions ]]
Common.AddCurrentTask("Objective")

local function HealthLogic(me)
    if (me:GetHealth() / me:GetMaxHealth()) * 100 < Menu.Main.SelfHealTreshold and not me:InCond(TFCond_Healing) then
        if not G.Current_Tasks[G.Tasks.Health] and Menu.Main.shouldfindhealth then
            Log:Info("Switching to health task")
            Common.AddCurrentTask("Health")
            Navigation.ClearPath()
        end
    else
        if G.Current_Tasks[G.Tasks.Health] then
            Log:Info("Health task no longer needed, switching back to objective task")
            Common.RemoveCurrentTask("Health")
            Navigation.ClearPath()
        end
    end
end

local function handleMemoryUsage()
    G.Benchmark.MemUsage = collectgarbage("count")
    if G.Benchmark.MemUsage / 1024 > 250 then
        collectgarbage()
        collectgarbage()
        collectgarbage()

        Log:Info("Trigger GC")
    end
end

-- Loads the nav file of the current map
local function LoadNavFile()
    local mapFile = engine.GetMapName()
    local navFile = string.gsub(mapFile, ".bsp", ".nav")
    Navigation.LoadFile(navFile)
    Navigation.ClearPath()
end

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if not Menu.Navigation.autoPath then return end
    local currentTask = Common.GetHighestPriorityTask()
    if not currentTask then return end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then
        Navigation.ClearPath()
        return
    end
    local flags = me:GetPropInt("m_fFlags")
    local myPos = me:GetAbsOrigin()

    WorkManager.addWork(HealthLogic, {me}, 33, "HealthLogic")
    WorkManager.addWork(handleMemoryUsage, {}, 44, "MemoryUsage")

    if userCmd:GetForwardMove() ~= 0 or userCmd:GetSideMove() ~= 0 then
        G.Navigation.currentNodeTicks = 0
        return
    elseif G.Navigation.path then
        if G.Navigation.currentNodePos then
            if Menu.Movement.lookatpath then
                local melnx = WPlayer.GetLocal()
                local angles = Lib.Utils.Math.PositionAngles(melnx:GetEyePos(), G.Navigation.currentNodePos)
                angles.x = 0

                if Menu.Movement.smoothLookAtPath then
                    local currentAngles = userCmd.viewangles
                    local deltaAngles = {x = angles.x - currentAngles.x, y = angles.y - currentAngles.y}

                    deltaAngles.y = ((deltaAngles.y + 180) % 360) - 180

                    angles = EulerAngles(currentAngles.x + deltaAngles.x * 0.05, currentAngles.y + deltaAngles.y * smoothFactor, 0)
                end
                engine.SetViewAngles(angles)
            end
        end

        local horizontalDist = math.abs(myPos.x - G.Navigation.currentNodePos.x) + math.abs(myPos.y - G.Navigation.currentNodePos.y)
        local verticalDist = math.abs(myPos.z - G.Navigation.currentNodePos.z)

        if (horizontalDist < G.Misc.NodeTouchDistance) and verticalDist <= G.Misc.NodeTouchHeight then
            Navigation.RemoveCurrentNode()
            Navigation.ResetTickTimer()

            if G.Navigation.currentNodeID < 1 then
                Navigation.ClearPath()
                Log:Info("Reached end of path")
                --Common.RemoveCurrentTask(currentTask)
            end
        else
            if G.Menu.Main.Skip_Nodes and WorkManager.attemptWork(2, "node skip") then
                if G.Navigation.currentNodeID > 1 then
                    local nextNode = G.Navigation.path[G.Navigation.currentNodeID - 1]
                    local nextHorizontalDist = math.abs(myPos.x - nextNode.pos.x) + math.abs(myPos.y - nextNode.pos.y)
                    local nextVerticalDist = math.abs(myPos.z - nextNode.pos.z)

                    if nextHorizontalDist < horizontalDist and nextVerticalDist <= G.Misc.NodeTouchHeight then
                        Log:Info("Skipping to closer node %d", G.Navigation.currentNodeID - 1)
                        Navigation.RemoveCurrentNode()
                    end
                end
            elseif G.Menu.Main.Optymise_Path and WorkManager.attemptWork(4, "Optymise Path") then
                OptimizePath()
            end

            G.Navigation.currentNodeTicks = G.Navigation.currentNodeTicks + 1 --increment movement timer if its too big it means we got stuck at some point
            Lib.TF2.Helpers.WalkTo(userCmd, me, G.Navigation.currentNodePos)
        end

        if me:EstimateAbsVelocity():Length() < 50 and (G.Navigation.currentNodeTicks > 44 or G.Navigation.currentNodeTicks > 122) then
            G.Misc.jumptimer = G.Misc.jumptimer + 1
            if WorkManager.attemptWork(10, "jumpCheck") and Navigation.isWalkable(myPos, G.Navigation.currentNodePos, 1) then
                if not me:InCond(TFCond_Zoomed) and flags & FL_ONGROUND == 1 then
                    if G.Misc.jumptimer > 66 then
                        userCmd:SetButtons(userCmd.buttons & (~IN_DUCK))
                        userCmd:SetButtons(userCmd.buttons & (~IN_JUMP))
                        userCmd:SetButtons(userCmd.buttons | IN_JUMP)
                        G.Misc.jumptimer = 0
                    else
                        userCmd:SetButtons(userCmd.buttons & (~IN_JUMP))
                    end
                end
            end
        end

        if flags & FL_ONGROUND == 1 then
            if G.Navigation.currentNodeTicks > 264 or (G.Navigation.currentNodeTicks > 22
            and horizontalDist < G.Misc.NodeTouchDistance)
            and WorkManager.attemptWork(20, "pathCheck") then

                if not Navigation.isWalkable(myPos, G.Navigation.currentNodePos, 1) then
                    Log:Warn("Path to node %d is blocked, removing connection and repathing...", G.Navigation.currentNodeIndex)
                    if G.Navigation.currentPath[G.Navigation.currentNodeIndex] and G.Navigation.currentPath[G.Navigation.currentNodeIndex + 1] then
                        Navigation.RemoveConnection(G.Navigation.currentPath[G.Navigation.currentNodeIndex], G.Navigation.currentPath[G.Navigation.currentNodeIndex + 1])
                    elseif G.Navigation.currentPath[G.Navigation.currentNodeIndex] and not G.Navigation.currentPath[G.Navigation.currentNodeIndex + 1] and G.Navigation.currentNodeIndex > 1 then
                        Navigation.RemoveConnection(G.Navigation.currentPath[G.Navigation.currentNodeIndex - 1], G.Navigation.currentPath[G.Navigation.currentNodeIndex])
                    end
                    Navigation.ClearPath()
                    Navigation.ResetTickTimer()
                elseif not WorkManager.attemptWork(5, "pathCheck") then
                    Log:Warn("Path to node %d is stuck but not blocked, repathing...", G.Navigation.currentNodeIndex)
                    Navigation.ClearPath()
                    Navigation.ResetTickTimer()
                end

            end
        end

    elseif not WorkManager.works["Pathfinding"] then
        local startNode = Navigation.GetClosestNode(myPos)
        if not startNode then
            Log:Warn("Could not find start node")
            return
        end

        local goalNode = nil
        local mapName = engine.GetMapName():lower()

        local function findPayloadGoal()
            G.World.payloads = entities.FindByClass("CObjectCartDispenser")
            for _, entity in pairs(G.World.payloads) do
                if entity:GetTeamNumber() == me:GetTeamNumber() then
                    return Navigation.GetClosestNode(entity:GetAbsOrigin())
                end
            end
        end

        local function findFlagGoal()
            local myItem = me:GetPropInt("m_hItem")
            G.World.flags = entities.FindByClass("CCaptureFlag")
            for _, entity in pairs(G.World.flags) do
                local myTeam = entity:GetTeamNumber() == me:GetTeamNumber()
                if (myItem > 0 and myTeam) or (myItem < 0 and not myTeam) then
                    return Navigation.GetClosestNode(entity:GetAbsOrigin())
                end
            end
        end

        local function findHealthGoal()
            local closestDist = math.huge
            local closestNode = nil
            for _, pos in pairs(G.World.healthPacks) do
                local healthNode = Navigation.GetClosestNode(pos)
                if healthNode then
                    local dist = (myPos - pos):Length()
                    if dist < closestDist then
                        closestDist = dist
                        closestNode = healthNode
                    end
                end
            end
            return closestNode
        end

        if currentTask == "Objective" then
            if mapName:find("plr_") or mapName:find("pl_") then
                goalNode = findPayloadGoal()
            elseif mapName:find("ctf_") then
                goalNode = findFlagGoal()
            else
                Log:Warn("Unsupported Gamemode, try CTF, PL, or PLR")
            end
        elseif currentTask == "Health" then
            goalNode = findHealthGoal()
        else
            Log:Debug("Unknown task: %s", currentTask)
            return
        end

        if not goalNode then
            Log:Warn("Could not find goal node")
            return
        end

        Log:Info("Generating new path from node %d to node %d", startNode.id, goalNode.id)
        WorkManager.addWork(Navigation.FindPath, {startNode, goalNode}, 33, "Pathfinding")
    end
    --WorkManager.processWorks() --for tasks taht were not given oportunity to run
end

---@param ctx DrawModelContext
local function OnDrawModel(ctx)
    if ctx:GetModelName():find("medkit") then
        local entity = ctx:GetEntity()
        G.World.healthPacks[entity:GetIndex()] = entity:GetAbsOrigin()
    end
end

---@param event GameEvent
local function OnGameEvent(event)
    local eventName = event:GetName()

    if eventName == "game_newmap" then
        Log:Info("New map detected, reloading nav file...")
        G:Reset()
        LoadNavFile()
        Navigation.FixAllNodes()
    end
end

callbacks.Unregister("Draw", "LNX.Lmaobot.Draw")
callbacks.Unregister("CreateMove", "LNX.Lmaobot.CreateMove")
callbacks.Unregister("DrawModel", "LNX.Lmaobot.DrawModel")
callbacks.Unregister("FireGameEvent", "LNX.Lmaobot.FireGameEvent")

callbacks.Register("Draw", "LNX.Lmaobot.Draw", OnDraw)
callbacks.Register("CreateMove", "LNX.Lmaobot.CreateMove", OnCreateMove)
callbacks.Register("DrawModel", "LNX.Lmaobot.DrawModel", OnDrawModel)
callbacks.Register("FireGameEvent", "LNX.Lmaobot.FireGameEvent", OnGameEvent)

--[[ Commands ]]

Commands.Register("pf_reload", function()
    LoadNavFile()
end)

Commands.Register("pf", function(args)
    if args:size() ~= 2 then
        print("Usage: pf <Start> <Goal>")
        return
    end

    local start = tonumber(args:popFront())
    local goal = tonumber(args:popFront())

    if not start or not goal then
        print("Start/Goal must be numbers!")
        return
    end

    local startNode = Navigation.GetNodeByID(start)
    local goalNode = Navigation.GetNodeByID(goal)

    if not startNode or not goalNode then
        print("Start/Goal node not found!")
        return
    end

    WorkManager.addTask(Navigation.FindPath, {startNode, goalNode}, 66, "Pathfinding")
end)

Commands.Register("pf_auto", function (args)
    Menu.Navigation.autoPath = G.Menu.Navigation.autoPath
    print("Auto path: " .. tostring(Menu.Navigation.autoPath))
end)

Notify.Alert("Lmaobot loaded!")
LoadNavFile()