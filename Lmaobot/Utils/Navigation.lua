---@alias Connection { count: integer, connections: integer[] }
---@alias Node { x: number, y: number, z: number, id: integer, c: { [1]: Connection, [2]: Connection, [3]: Connection, [4]: Connection } }

local Common = require("Lmaobot.Common")
local G = require("Lmaobot.Utils.Globals")
local SourceNav = require("Lmaobot.SourceNav")
local AStar = require("Lmaobot.A-Star")
local Lib, Log = Common.Lib, Common.Log

local FS = Lib.Utils.FileSystem

---@class Pathfinding
local Navigation = {}

-- Add a connection between two nodes
function Navigation.AddConnection(nodeA, nodeB)
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    local nodes = G.Navigation.nodes

    for dir = 1, 4 do
        local conDir = nodes[nodeA.id].c[dir]
        if not conDir.connections[nodeB.id] then
            print("Adding connection between " .. nodeA.id .. " and " .. nodeB.id)
            table.insert(conDir.connections, nodeB.id)
            conDir.count = conDir.count + 1
        end
    end

    for dir = 1, 4 do
        local conDir = nodes[nodeB.id].c[dir]
        if not conDir.connections[nodeA.id] then
            print("Adding reverse connection between " .. nodeB.id .. " and " .. nodeA.id)
            table.insert(conDir.connections, nodeA.id)
            conDir.count = conDir.count + 1
        end
    end
end

-- Remove a connection between two nodes
function Navigation.RemoveConnection(nodeA, nodeB)
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    local nodes = G.Navigation.nodes

    for dir = 1, 4 do
        local conDir = nodes[nodeA.id].c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeB.id then
                print("Removing connection between " .. nodeA.id .. " and " .. nodeB.id)
                table.remove(conDir.connections, i)
                conDir.count = conDir.count - 1
                break
            end
        end
    end

    for dir = 1, 4 do
        local conDir = nodes[nodeB.id].c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeA.id then
                print("Removing reverse connection between " .. nodeB.id .. " and " .. nodeA.id)
                table.remove(conDir.connections, i)
                conDir.count = conDir.count - 1
                break
            end
        end
    end
end

-- Add cost to a connection between two nodes
function Navigation.AddCostToConnection(nodeA, nodeB, cost)
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    local nodes = G.Navigation.nodes

    for dir = 1, 4 do
        local conDir = nodes[nodeA.id].c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeB.id then
                print("Adding cost between " .. nodeA.id .. " and " .. nodeB.id)
                conDir.connections[i] = {node = con, cost = cost}
                break
            end
        end
    end

    for dir = 1, 4 do
        local conDir = nodes[nodeB.id].c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeA.id then
                print("Adding cost between " .. nodeB.id .. " and " .. nodeA.id)
                conDir.connections[i] = {node = con, cost = cost}
                break
            end
        end
    end
end

-- Fix a node by adjusting its height based on TraceLine results from the corners
---@param nodeId integer The index of the node in the Nodes table
---@return Node The fixed node
function Navigation.FixNode(nodeId)
    local nodes = G.Navigation.nodes
    local node = nodes[nodeId]
    if not node or not node.pos then
        print("Node with ID " .. tostring(nodeId) .. " is invalid or missing position, exiting function")
        return nil
    end

    if node.fixed then
        return node
    end

    local upVector = Vector3(0, 0, 72)
    local downVector = Vector3(0, 0, -144)
    local nodePos = node.pos
    local nwPos = node.nw + upVector
    local sePos = node.se + upVector
    local nePos = Vector3(node.nw.x, node.se.y, node.nw.z) + upVector
    local swPos = Vector3(node.se.x, node.nw.y, node.se.z) + upVector

    local positions = {nwPos, nePos, swPos, sePos}
    local lowestFraction = math.huge
    local bestZ = nodePos.z
    local validTraceFound = false

    for _, pos in ipairs(positions) do
        local traceResult = engine.TraceLine(pos, pos + downVector, TRACE_MASK)
        if traceResult.fraction > 0 and traceResult.fraction < lowestFraction then
            lowestFraction = traceResult.fraction
            bestZ = traceResult.endpos.z
            validTraceFound = true
        end
    end

    if validTraceFound then
        node.pos.z = bestZ
    else
        node.pos.z = nodePos.z + 18
    end

    node.fixed = true
    return node
end


-- Set the raw nodes and copy them to the fixed nodes table
---@param nodes Node[]
function Navigation.SetRawNodes(nodes)
    G.Navigation.rawNodes = nodes
    G.Navigation.nodes = Lib.Utils.DeepCopy(nodes)
    Navigation.FixAllNodes()
end

-- Get the fixed nodes used for calculations
---@return Node[]
function Navigation.GetNodes()
    return G.Navigation.nodes
end

-- Get the raw nodes
---@return Node[]
function Navigation.GetRawNodes()
    return G.Navigation.rawNodes
end

-- Fix all nodes by adjusting their positions
function Navigation.FixAllNodes()
    for id, node in pairs(G.Navigation.nodes) do
        Navigation.FixNode(id)
    end
end

-- Set the current path
---@param path Node[]
function Navigation.SetCurrentPath(path)
    if not path then
        Log:Error("Failed to set path, it's nil")
        return
    end
    G.Navigation.path = path
end

-- Get the current path
---@return Node[]|nil
function Navigation.GetCurrentPath()
    return G.Navigation.path
end

-- Clear the current path
function Navigation.ClearPath()
    G.Navigation.path = {}
end

-- Get a node by its ID
---@param id integer
---@return Node
function Navigation.GetNodeByID(id)
    return G.Navigation.nodes[id]
end

-- Remove the current node from the path
function Navigation.RemoveCurrentNode()
    G.Navigation.currentNodeTicks = 0
    table.remove(G.Navigation.path)
end

-- Function to increment the current node ticks
function Navigation.increment_ticks()
    G.Navigation.currentNodeTicks =  G.Navigation.currentNodeTicks + 1
end

-- Function to increment the current node ticks
function Navigation.ResetTickTimer()
    G.Navigation.currentNodeTicks = 0
end

-- Constants
local STEP_HEIGHT = 18
local MAX_SIMULATION_TICKS = 5
local HULL_MIN = G.pLocal.vHitbox.Min
local HULL_MAX = G.pLocal.vHitbox.Max

-- Checks for an obstruction between two points using a hull trace.
local function isPathClear(startPos, endPos)
    local traceResult = engine.TraceHull(startPos, endPos, HULL_MIN, HULL_MAX, MASK_PLAYERSOLID_BRUSHONLY)
    return traceResult.fraction == 1
end

-- Checks if the ground is stable at a given position.
local function isGroundStable(position)
    local groundTraceStart = position + Vector3(0, 0, 5)
    local groundTraceEnd = position + Vector3(0, 0, -67)
    local groundTraceResult = engine.TraceLine(groundTraceStart, groundTraceEnd, MASK_PLAYERSOLID_BRUSHONLY)
    return groundTraceResult.fraction < 1
end

-- Simulates a fast walk between two points, checking for collisions and step handling.
local function simulateFastWalk(startPos, endPos)
    local currentPosition = startPos
    local direction = (endPos - startPos):Normalized()
    local totalDistance = (endPos - startPos):Length()
    local stepSize = totalDistance / MAX_SIMULATION_TICKS
    local currentDistance = 0

    while currentDistance < totalDistance do
        local nextPosition = currentPosition + direction * stepSize

        -- Check if the next step is clear
        if not isPathClear(currentPosition, nextPosition) then
            -- Try to step up
            local stepUpPosition = nextPosition + Vector3(0, 0, STEP_HEIGHT)
            if isPathClear(currentPosition, stepUpPosition) and isGroundStable(stepUpPosition) then
                currentPosition = stepUpPosition
            else
                return false, currentPosition -- Path is blocked
            end
        else
            currentPosition = nextPosition
        end

        -- Check if the ground is stable
        if not isGroundStable(currentPosition) then
            return false, currentPosition -- Unstable ground detected
        end

        currentDistance = (currentPosition - startPos):Length()
    end

    return true, currentPosition -- Path is walkable
end

-- Main function to check if the path between the current position and the node is walkable.
function Navigation.isWalkable(startPos, endPos)
    -- Simulate the walk between start and end positions
    local walkable, finalPosition = simulateFastWalk(startPos, endPos)
    return walkable, finalPosition
end

--[[Checks for an obstruction between two points using a line trace, then a hull trace if necessary.
local function isPathClear(startPos, endPos)
    local lineTraceResult = engine.TraceLine(startPos, endPos, TRACE_MASK)
    if lineTraceResult.fraction < 1 then
        return false
    end

    local traceResult = engine.TraceHull(startPos, endPos, HULL_MIN, HULL_MAX, TRACE_MASK)
    if traceResult.fraction == 1 then
        return true
    else
        local upVector = Vector3(0, 0, 72)
        traceResult = engine.TraceHull(startPos + upVector, endPos, HULL_MIN, HULL_MAX, TRACE_MASK)
        return traceResult.fraction == 1
    end
end

-- Checks if the ground is stable at a given position.
local function isGroundStable(position)
    local groundTraceStart = position + Vector3(0, 0, 5)
    local groundTraceEnd = position + Vector3(0, 0, -67)
    local groundTraceResult = engine.TraceLine(groundTraceStart, groundTraceEnd, TRACE_MASK)
    return groundTraceResult.fraction < 1
end

-- Checks if the path segments are safe from falling off a cliff using iterative binary search.
local function isPathSafeFromCliff(startPos, endPos, maxDepth)
    local positionsToCheck = {startPos, endPos}
    for depth = 1, maxDepth do
        local newPositions = {}
        for i = 1, #positionsToCheck - 1 do
            local pos1 = positionsToCheck[i]
            local pos2 = positionsToCheck[i + 1]
            local midPos = (pos1 + pos2) / 2

            -- Check if the ground is stable at the midpoint
            if not isGroundStable(midPos) then
                return false
            end

            -- Add new positions to check in the next iteration
            table.insert(newPositions, pos1)
            table.insert(newPositions, midPos)
        end
        table.insert(newPositions, endPos)
        positionsToCheck = newPositions
    end

    return true
end

-- Main function to check if the path between the current position and the node is walkable.
function Navigation.isWalkable(startPos, endPos, maxDepth)
    -- Check if the ground is stable at start, mid, and end positions
    local midPos = (startPos + endPos) / 2
    if not isGroundStable(startPos) or not isGroundStable(midPos) or not isGroundStable(endPos) then
        return false
    end

    -- Check if the path between start and end is clear
    if not isPathClear(startPos, endPos) then
        return false
    end

    -- Ensure the path segments are safe from falling off a cliff
    if not isPathSafeFromCliff(startPos, endPos, maxDepth) then
        return false
    end

    return true
end]]


--- Finds the closest walkable node from the player's current position in reverse order (from last to first).
-- @param currentPath table The current path consisting of nodes.
-- @param myPos Vector3 The player's current position.
-- @param currentNodeIndex number The index of the current node in the path.
-- @return number, Node, Vector3 The index, node, and position of the closest walkable node in reverse order.
function Navigation.FindBestNode(currentPath, myPos, currentNodeIndex)
    local lastWalkableNodeIndex = nil
    local lastWalkableNode = nil
    local lastWalkableNodePos = nil

    for i = currentNodeIndex, 1, -1 do
        local node = currentPath[i]
        node = Navigation.FixNode(node.id)
        local nodePos = node.pos
        local distance = (myPos - nodePos):Length()

        if distance <= 700 and Navigation.isWalkable(myPos, nodePos) then
            lastWalkableNodeIndex = i
            lastWalkableNode = node
            lastWalkableNodePos = nodePos
        elseif distance > 700 then
            break
        end
    end

    return lastWalkableNodeIndex, lastWalkableNode, lastWalkableNodePos
end

-- Constants for hull dimensions and trace masks
local HULL_MIN = Vector3(-24, -24, 0)
local HULL_MAX = Vector3(24, 24, 82)
local TRACE_MASK = MASK_PLAYERSOLID

-- Constants
local MIN_SPEED = 0
local MAX_SPEED = 450
local TICK_RATE = 66

local ClassForwardSpeeds = {
    [E_Character.TF2_Scout] = 400,
    [E_Character.TF2_Soldier] = 240,
    [E_Character.TF2_Pyro] = 300,
    [E_Character.TF2_Demoman] = 280,
    [E_Character.TF2_Heavy] = 230,
    [E_Character.TF2_Engineer] = 300,
    [E_Character.TF2_Medic] = 320,
    [E_Character.TF2_Sniper] = 300,
    [E_Character.TF2_Spy] = 320
}

-- Function to get forward speed by class
function Navigation.GetForwardSpeedByClass(pLocal)
    local pLocalClass = pLocal:GetPropInt("m_iClass")
    return ClassForwardSpeeds[pLocalClass]
end

-- Function to compute the move direction
local function ComputeMove(pCmd, a, b)
    local diff = (b - a)
    if diff:Length() == 0 then return Vector3(0, 0, 0) end

    local x = diff.x
    local y = diff.y
    local vSilent = Vector3(x, y, 0)

    local ang = vSilent:Angles()
    local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
    local yaw = math.rad(ang.y - cYaw)
    local move = Vector3(math.cos(yaw), -math.sin(yaw), 0)

    return move
end

-- Function to make the player walk to a destination smoothly
function Navigation.WalkTo(pCmd, pLocal, pDestination)
    local localPos = pLocal:GetAbsOrigin()
    local distVector = pDestination - localPos
    local dist = distVector:Length()
    local currentSpeed = Navigation.GetForwardSpeedByClass(pLocal)
    local currentVelocity = pLocal:EstimateAbsVelocity()
    local velocityDirection = Common.Normalize(currentVelocity)
    local velocitySpeed = currentVelocity:Length()

    local distancePerTick = math.max(10, math.min(currentSpeed / TICK_RATE, 450))

    if dist > distancePerTick then
        local result = ComputeMove(pCmd, localPos, pDestination)
        pCmd:SetForwardMove(result.x)
        pCmd:SetSideMove(result.y)
    else
        local result = ComputeMove(pCmd, localPos, pDestination)
        local scaleFactor = dist / 1000
        pCmd:SetForwardMove(result.x * scaleFactor)
        pCmd:SetSideMove(result.y * scaleFactor)
    end
end

-- Attempts to read and parse the nav file
---@param navFilePath string
---@return table|nil, string|nil
local function tryLoadNavFile(navFilePath)
    local file = io.open(navFilePath, "rb")
    if not file then
        return nil, "File not found"
    end

    local content = file:read("*a")
    file:close()

    local navData = SourceNav.parse(content)
    if not navData or #navData.areas == 0 then
        return nil, "Failed to parse nav file or no areas found."
    end

    return navData
end

-- Generates the nav file
local function generateNavFile()
    client.RemoveConVarProtection("sv_cheats")
    client.RemoveConVarProtection("nav_generate")
    client.SetConVar("sv_cheats", "1")
    client.Command("nav_generate", true)
    Log:Info("Generating nav file. Please wait...")

    local navGenerationDelay = 10
    local startTime = os.time()
    repeat
        if os.time() - startTime > navGenerationDelay then
            break
        end
    until false
end

-- Processes nav data to create nodes
---@param navData table
---@return table
local function processNavData(navData)
    local navNodes = {}
    for _, area in ipairs(navData.areas) do
        local cX = (area.north_west.x + area.south_east.x) / 2
        local cY = (area.north_west.y + area.south_east.y) / 2
        local cZ = (area.north_west.z + area.south_east.z) / 2

        navNodes[area.id] = {
            pos = Vector3(cX, cY, cZ),
            id = area.id,
            c = area.connections,
            nw = area.north_west,
            se = area.south_east,
            fixed = nil,
        }
    end
    return navNodes
end

-- Main function to load the nav file
---@param navFile string
function Navigation.LoadFile(navFile)
    local fullPath = "tf/" .. navFile
    local navData, error = tryLoadNavFile(fullPath)

    if not navData and error == "File not found" then
        generateNavFile()
        navData, error = tryLoadNavFile(fullPath)
        if not navData then
            Log:Error("Failed to load or parse generated nav file: " .. error)
            return
        end
    elseif not navData then
        Log:Error(error)
        return
    end

    local navNodes = processNavData(navData)
    Log:Info("Parsed %d areas from nav file.", #navNodes)
    Navigation.SetRawNodes(navNodes)
end

function Navigation.OptimizePath()
    local path = G.Navigation.path
    local currentIndex = G.Navigation.FirstAgentNode
    local checkingIndex = G.Navigation.SecondAgentNode
    local currentNode = G.Navigation.currentNodeID -- Assuming this is correctly set somewhere in your game logic
    local optimizationLimit = G.Menu.Main.OptimizationLimit or 10 -- Default limit if not specified

    -- Only proceed if the first agent is not too far ahead of the current node
    if currentIndex - currentNode <= optimizationLimit then
        -- Check visibility between the current node and the checking node
        if checkingIndex <= #path and G.Navigation.isWalkable(path[currentIndex], path[checkingIndex]) then
            -- If the current node can directly walk to the checking node, move to check the next node
            checkingIndex = checkingIndex + 1
        else
            -- Once we find a node that cannot be directly walked to, we place all nodes in a straight line
            -- from currentIndex to the last directly walkable node (checkingIndex - 1)
            if checkingIndex > currentIndex + 1 then
                local startX, startY = path[currentIndex].pos.x, path[currentIndex].pos.y
                local endX, endY = path[checkingIndex - 1].pos.x, path[checkingIndex - 1].pos.y
                local numSteps = checkingIndex - currentIndex - 1
                local stepX = (endX - startX) / (numSteps + 1)
                local stepY = (endY - startY) / (numSteps + 1)
                for i = 1, numSteps do
                    local nodeIndex = currentIndex + i
                    local node = path[nodeIndex]
                    node.pos.x = startX + stepX * i
                    node.pos.y = startY + stepY * i
                    -- Reset fixed status before applying new fix
                    node.fixed = nil
                    -- Call FixNode to adjust node's height and validate it
                    Navigation.FixNode(nodeIndex)
                end
            end

            -- Update the indices in the G module to start a new segment of optimization
            G.Navigation.FirstAgentNode = checkingIndex - 1
            G.Navigation.SecondAgentNode = G.Navigation.FirstAgentNode + 1

            -- Reset the indices to the beginning if we've reached or exceeded the last node
            if G.Navigation.FirstAgentNode >= #path - 1 then
                G.Navigation.FirstAgentNode = 1
                G.Navigation.SecondAgentNode = G.Navigation.FirstAgentNode + 1
            end
        end
    end
end

---@param pos Vector3|{ x:number, y:number, z:number }
---@return Node
function Navigation.GetClosestNode(pos)
    local closestNode = nil
    local closestDist = math.huge

    for _, node in pairs(G.Navigation.nodes) do
        local dist = (node.pos - pos):Length()
        if dist < closestDist then
            closestNode = node
            closestDist = dist
        end
    end

    return closestNode
end

-- Returns all adjacent nodes of the given node
---@param node Node
---@param nodes Node[]
local function GetAdjacentNodes(node, nodes)
    local adjacentNodes = {}

    for dir = 1, 4 do
        local conDir = node.c[dir]
        for _, con in pairs(conDir.connections) do
            local conNode = nodes[con]
            if conNode then
                -- Calculate horizontal and vertical conditions
                local conNodeNW = conNode.nw
                local conNodeSE = conNode.se

                local horizontalCheck = ((conNodeNW.x - node.se.x) * (node.nw.x - conNodeSE.x) *
                                         (conNodeNW.y - node.se.y) * (node.nw.y - conNodeSE.y)) <= 0 and 1 or 0

                local verticalCheck = (conNode.z - (node.z - 70)) * ((node.z + 70) - conNode.z) >= 0 and 1 or 0

                -- If both conditions are met, add the connected node to adjacent nodes
                local addNode = horizontalCheck * verticalCheck
                adjacentNodes[#adjacentNodes + addNode] = conNode
            end
        end
    end

    return adjacentNodes
end

---@param startNode Node
---@param goalNode Node
---@param maxNodes number
function Navigation.FindPath(startNode, goalNode, maxNodes)
    if not startNode then
        Log:Warn("Invalid start node!")
        return
    end

    if not goalNode then
        Log:Warn("Invalid goal node!")
        return
    end

    if Navigation.isWalkable(startNode, goalNode) then
        G.Navigation.path = {goalNode}
    else
        G.Navigation.path = AStar.Path(startNode, goalNode, G.Navigation.nodes, GetAdjacentNodes, maxNodes)
    end

    if not G.Navigation.path or #G.Navigation.path == 0 then
        Log:Error("Failed to find path from %d to %d!", startNode.id, goalNode.id)
        G.Navigation.path = nil
    else
        Log:Info("Path found from %d to %d with %d nodes", startNode.id, goalNode.id, #G.Navigation.path)
    end
end

return Navigation