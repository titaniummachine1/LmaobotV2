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

local Notify, Commands, WPlayer = Lib.UI.Notify, Lib.Utils.Commands, Lib.TF2.WPlayer
local Log = Lib.Utils.Logger.new("Lmaobot")
Log.Level = 0

--[[ Functions ]]
Common.AddCurrentTask("Objective")

local function HealthLogic(pLocal)
    if (pLocal:GetHealth() / pLocal:GetMaxHealth()) * 100 < G.Menu.Main.SelfHealTreshold and not pLocal:InCond(TFCond_Healing) then
        if not G.Current_Tasks[G.Tasks.Health] and G.Menu.Main.shouldfindhealth then
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
    if G.Benchmark.MemUsage / 1024 > 450 then
        collectgarbage()
        collectgarbage()
        collectgarbage()

        Log:Info("Trigger GC")
    end
end

G.StateDefinition = table.readOnly {
    Idle = { --1 determine if should work ,if yes look for work
        inactive = 1, --truce active or cant fight or move
        active = 2, --good look for work now
    },
    Walking = { --2 --walk directly to target
        default = { --walk to target
            Normal = 1, --walk to target
            SmartJump = 2, --walk to target assume you need to jump
        },
        Stuck = 3, -- stuck try to get unstuck
    },
    Navigation = { --3 --navigate map to target
        default = { --walk to target
            Normal = 1, --walk to target
            SmartJump = 2, --walk to target assume you need to jump
        },
        Stuck = 3, -- stuck try to get unstuck
    },
    Maintnance = { --4 -- medpack/ammo pickup phaze
        LowAmmo = 1, --navigate to ammo
        LowHealth = 2, --navigate to healthpack or dispenser or until get healed by medic.
        Stuck = 3, -- stuck try to get unstuck
    },
    Pocketing = { --5 --medic mode
        Medigun = 1, --use medigun
        Crossbow = 2, --Use Crossbow spike
        Sacrofice = 3, --sacrofice when loosing fight go towards left side of enemy hitbox from origin of friend to blok enemy bullets.
    },
    SelfDefense = { --6 --self defense
        Crossbow = 1, --long/medium distance atacking
        Melee = 2, --short/point blank distance atack go towards target try predictign his movement
        StepBack = 3, --move away from target after melee atack
        Run = 4, --look for any teammate or go to spawn when not in imidiete danger
    },
}

G.States = {
    {
        func = function()
            
        end,
        substates = {
            {
                func = function() print("Executing State 1.1") end,
                substates = {
                    { func = function() print("Executing State 1.1.1") end },
                    { func = function() print("Executing State 1.1.2") end }
                }
            },
            {
                func = function() print("Executing State 1.2") end,
                substates = {
                    { func = function() print("Executing State 1.2.1") end },
                    { func = function() print("Executing State 1.2.2") end }
                }
            }
        }
    },
    {
        func = function() print("Executing State 2") end,
        substates = {
            {
                func = function() print("Executing State 2.1") end,
                substates = {
                    { func = function() print("Executing State 2.1.1") end },
                    { func = function() print("Executing State 2.1.2") end }
                }
            },
            {
                func = function() print("Executing State 2.2") end,
                substates = {
                    { func = function() print("Executing State 2.2.1") end },
                    { func = function() print("Executing State 2.2.2") end }
                }
            }
        }
    }
}

G.saveGlobalState() --save wahtever i did here XD

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if not G.Menu.Navigation.autoPath then return end
    local currentTask = Common.GetHighestPriorityTask()
    if not currentTask then return end

    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then
        Navigation.ClearPath()
        return
    end

    G.pLocal.entity = pLocal
    G.pLocal.flags = pLocal:GetPropInt("m_fFlags")
    G.pLocal.Origin = pLocal:GetAbsOrigin()

    --G.executeStateChain(G.States, G.state)

    if userCmd:GetForwardMove() ~= 0 or userCmd:GetSideMove() ~= 0 then
        G.Navigation.currentNodeTicks = 0
        return
    elseif G.Navigation.path then

        WorkManager.addWork(HealthLogic, {pLocal}, 33, "HealthLogic")
        WorkManager.addWork(handleMemoryUsage, {}, 44, "MemoryUsage")

        if G.Navigation.currentNodePos then
            if G.Menu.Movement.lookatpath then
                local pLocalWrapped = WPlayer.GetLocal()
                local angles = Lib.Utils.Math.PositionAngles(pLocalWrapped:GetEyePos(), G.Navigation.currentNodePos)
                angles.x = 0

                if G.Menu.Movement.smoothLookAtPath then
                    local currentAngles = userCmd.viewangles
                    local deltaAngles = {x = angles.x - currentAngles.x, y = angles.y - currentAngles.y}

                    deltaAngles.y = ((deltaAngles.y + 180) % 360) - 180

                    angles = EulerAngles(currentAngles.x + deltaAngles.x * 0.05, currentAngles.y + deltaAngles.y * G.Menu.Main.smoothFactor, 0)
                end
                engine.SetViewAngles(angles)
            end
        end

        local LocalOrigin = G.pLocal.Origin
        local horizontalDist = math.abs(LocalOrigin.x - G.Navigation.currentNodePos.x) + math.abs(LocalOrigin.y - G.Navigation.currentNodePos.y)
        local verticalDist = math.abs(LocalOrigin.z - G.Navigation.currentNodePos.z)

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
                    local nextHorizontalDist = math.abs(LocalOrigin.x - nextNode.pos.x) + math.abs(LocalOrigin.y - nextNode.pos.y)
                    local nextVerticalDist = math.abs(LocalOrigin.z - nextNode.pos.z)

                    if nextHorizontalDist < horizontalDist and nextVerticalDist <= G.Misc.NodeTouchHeight then
                        Log:Info("Skipping to closer node %d", G.Navigation.currentNodeID - 1)
                        Navigation.RemoveCurrentNode()
                    end
                end
            elseif G.Menu.Main.Optymise_Path and WorkManager.attemptWork(4, "Optymise Path") then
                Navigation.OptimizePath()
            end

            G.Navigation.currentNodeTicks = G.Navigation.currentNodeTicks + 1 --increment movement timer if its too big it means we got stuck at some point
            Lib.TF2.Helpers.WalkTo(userCmd, pLocal, G.Navigation.currentNodePos)
        end

        if G.pLocal.flags & FL_ONGROUND == 1 or pLocal:EstimateAbsVelocity():Length() < 50 then --if on ground or stuck
            if G.Navigation.currentNodeTicks > 66 then
                if WorkManager.attemptWork(132, "Unstuck_Jump") then
                    if not pLocal:InCond(TFCond_Zoomed) and G.pLocal.flags & FL_ONGROUND == 1 then
                        userCmd:SetButtons(userCmd.buttons & (~IN_DUCK))
                        userCmd:SetButtons(userCmd.buttons & (~IN_JUMP))
                        userCmd:SetButtons(userCmd.buttons | IN_JUMP)
                    end
                end
            end

            if G.Navigation.currentNodeTicks > 264 or (G.Navigation.currentNodeTicks > 22
            and horizontalDist < G.Misc.NodeTouchDistance)
            and WorkManager.attemptWork(66, "pathCheck") then

                if not Navigation.isWalkable(LocalOrigin, G.Navigation.currentNodePos, 1) then
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
        local LocalOrigin = G.pLocal.Origin
        local startNode = Navigation.GetClosestNode(LocalOrigin)
        if not startNode then
            Log:Warn("Could not find start node")
            return
        end

        local goalNode = nil
        local mapName = engine.GetMapName():lower()

        local function findPayloadGoal()
            G.World.payloads = entities.FindByClass("CObjectCartDispenser")
            for _, entity in pairs(G.World.payloads) do
                if entity:GetTeamNumber() == pLocal:GetTeamNumber() then
                    return Navigation.GetClosestNode(entity:GetAbsOrigin())
                end
            end
        end

        local function findFlagGoal()
            local myItem = pLocal:GetPropInt("m_hItem")
            G.World.flags = entities.FindByClass("CCaptureFlag")
            for _, entity in pairs(G.World.flags) do
                local myTeam = entity:GetTeamNumber() == pLocal:GetTeamNumber()
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
                    local dist = (LocalOrigin - pos):Length()
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
        Common.Setup()
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
    Common.Setup()
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
    G.Menu.Navigation.autoPath = G.Menu.Navigation.autoPath
    print("Auto path: " .. tostring(G.Menu.Navigation.autoPath))
end)

Notify.Alert("Lmaobot loaded!")
Common.Setup() --relaod whole script