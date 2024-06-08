---@alias Connection { count: integer, connections: integer[] }
---@alias Node { x: number, y: number, z: number, id: integer, c: { [1]: Connection, [2]: Connection, [3]: Connection, [4]: Connection } }
---@class Pathfinding
local Navigation = {}

local Common = require("Lmaobot.Utils.Common")
local G = require("Lmaobot.Utils.Globals")
local SourceNav = require("Lmaobot.Utils.SourceNav")
local AStar = require("Lmaobot.Utils.A-Star")
local Lib, Log = Common.Lib, Common.Log

-- Constants
local STEP_HEIGHT = 18
local DROP_HEIGHT = 144  -- Define your constants outside the function
local Jump_Height = 72 --duck jump height
local MAX_SLOPE_ANGLE = 55 -- Maximum angle (in degrees) that is climbable
local GRAVITY = 800 -- Gravity in units per second squared
local MIN_STEP_SIZE = 5 -- Minimum step size in units
local preferredSteps = 10 --prefered number oif steps for simulations
local HULL_MIN = G.pLocal.vHitbox.Min
local HULL_MAX = G.pLocal.vHitbox.Max
local TRACE_MASK = MASK_PLAYERSOLID
local TICK_RATE = 66

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

-- Perform a trace hull down from the given position to the ground
---@param position Vector3 The start position of the trace
---@param hullSize table The size of the hull
---@return Vector3 The normal of the ground at that point
local function traceHullDown(position, hullSize)
    local endPos = position - Vector3(0, 0, DROP_HEIGHT)  -- Adjust the distance as needed
    local traceResult = engine.TraceHull(position, endPos, hullSize.min, hullSize.max, MASK_PLAYERSOLID_BRUSHONLY)
    return traceResult.plane  -- Directly using the plane as the normal
end

-- Perform a trace line down from the given position to the ground
---@param position Vector3 The start position of the trace
---@return Vector3 The hit position
local function traceLineDown(position)
    local endPos = position - Vector3(0, 0, DROP_HEIGHT)
    local traceResult = engine.TraceLine(position, endPos, TRACE_MASK)
    return traceResult.endpos
end

-- Calculate the remaining two corners based on the adjusted corners and ground normal
---@param corner1 Vector3 The first adjusted corner
---@param corner2 Vector3 The second adjusted corner
---@param normal Vector3 The ground normal
---@param height number The height of the rectangle
---@return table The remaining two corners
local function calculateRemainingCorners(corner1, corner2, normal, height)
    local widthVector = corner2 - corner1
    local widthLength = widthVector:Length2D()

    local heightVector = Vector3(-widthVector.y, widthVector.x, 0)

    local function rotateAroundNormal(vector, angle)
        local cosTheta = math.cos(angle)
        local sinTheta = math.sin(angle)
        return Vector3(
            (cosTheta + (1 - cosTheta) * normal.x^2) * vector.x + ((1 - cosTheta) * normal.x * normal.y - normal.z * sinTheta) * vector.y + ((1 - cosTheta) * normal.x * normal.z + normal.y * sinTheta) * vector.z,
            ((1 - cosTheta) * normal.x * normal.y + normal.z * sinTheta) * vector.x + (cosTheta + (1 - cosTheta) * normal.y^2) * vector.y + ((1 - cosTheta) * normal.y * normal.z - normal.x * sinTheta) * vector.z,
            ((1 - cosTheta) * normal.x * normal.z - normal.y * sinTheta) * vector.x + ((1 - cosTheta) * normal.y * normal.z + normal.x * sinTheta) * vector.y + (cosTheta + (1 - cosTheta) * normal.z^2) * vector.z
        )
    end

    local rotatedHeightVector = rotateAroundNormal(heightVector, math.pi / 2)

    local corner3 = corner1 + rotatedHeightVector * (height / widthLength)
    local corner4 = corner2 + rotatedHeightVector * (height / widthLength)

    return { corner3, corner4 }
end

-- Fix a node by adjusting its height based on TraceLine results from the corners
---@param nodeId integer The index of the node in the Nodes table
function Navigation.FixNode(nodeId)
    local nodes = G.Navigation.nodes
    local node = nodes[nodeId]
    if not node or not node.pos then
        print("Node with ID " .. tostring(nodeId) .. " is invalid or missing position, exiting function")
        return
    end

    -- Step 1: Raise the corners by a defined height
    local raiseVector = Vector3(0, 0, Jump_Height)
    local raisedNWPos = node.nw + raiseVector
    local raisedSEPos = node.se + raiseVector

    -- Step 2: Calculate the middle position after raising the corners
    local middlePos = (raisedNWPos + raisedSEPos) / 2

    -- Step 3: Perform trace hull down from the middle position to get the ground normal
    local traceHullSize = {
        -- Clamp the size to player hitbox size to avoid staircase issues
        min = Vector3(math.max(-math.abs(raisedNWPos.x - raisedSEPos.x) / 2, HULL_MIN.x), math.max(-math.abs(raisedNWPos.y - raisedSEPos.y) / 2, HULL_MIN.y), 0),
        max = Vector3(math.min(math.abs(raisedNWPos.x - raisedSEPos.x) / 2, HULL_MAX.x), math.min(math.abs(raisedNWPos.y - raisedSEPos.y) / 2, HULL_MAX.y), 45)
    }

    local groundNormal = traceHullDown(middlePos, traceHullSize)

    -- Step 4: Calculate the remaining corners based on the ground normal
    local height = math.abs(node.nw.y - node.se.y)
    local remainingCorners = calculateRemainingCorners(raisedNWPos, raisedSEPos, groundNormal, height)

    -- Step 5: Adjust corners to align with the ground normal
    raisedNWPos = traceLineDown(raisedNWPos)
    raisedSEPos = traceLineDown(raisedSEPos)
    remainingCorners[1] = traceLineDown(remainingCorners[1])
    remainingCorners[2] = traceLineDown(remainingCorners[2])

    -- Step 6: Update node with new corners and position
    node.nw = raisedNWPos
    node.se = raisedSEPos
    node.ne = remainingCorners[1]
    node.sw = remainingCorners[2]

    -- Step 7: Recalculate the middle position based on the fixed corners
    local finalMiddlePos = (raisedNWPos + raisedSEPos) / 2
    node.pos = finalMiddlePos

    G.Navigation.nodes[nodeId] = node -- Set the fixed node to the global node
end

-- Adjust all nodes by fixing their positions and adding missing corners.
function Navigation.FixAllNodes()
    local nodes = Navigation.GetNodes()
    for id in pairs(nodes) do
        Navigation.FixNode(id)
    end
end

-- Set the raw nodes and copy them to the fixed nodes table
---@param nodes Node[]
function Navigation.SetNodes(nodes)
    G.Navigation.rawNodes = nodes
    G.Navigation.nodes = Lib.Utils.DeepCopy(nodes)
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

-- Set the current path
---@param path Node[]
function Navigation.SetCurrentPath(path)
    if not path then
        Log:Error("Failed to set path, it's nil")
        return
    end
    G.Navigation.path = path
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

-- Function to convert degrees to radians
local function degreesToRadians(degrees)
    return degrees * math.pi / 180
end

-- Function to get the ground normal at a given position
local function getGroundNormal(position)
    local groundTraceStart = position + Vector3(0, 0, 5)
    local groundTraceEnd = position + Vector3(0, 0, -67)
    local groundTraceResult = engine.TraceLine(groundTraceStart, groundTraceEnd, MASK_PLAYERSOLID_BRUSHONLY)
    return groundTraceResult.plane
end

-- Function to adjust direction based on ground normal
local function adjustDirectionToGround(direction, groundNormal)
    local upVector = Vector3(0, 0, 1)
    local angleBetween = math.acos(groundNormal:Dot(upVector))
    if angleBetween <= degreesToRadians(MAX_SLOPE_ANGLE) then
        local newDirection = direction:Cross(upVector):Cross(groundNormal)
        return newDirection:Normalized()
    end
    return direction -- If the slope is too steep, keep the original direction
end

-- Checks for an obstruction between two points using a hull trace.
local function isPathClear(startPos, endPos)
    local traceResult = engine.TraceHull(startPos, endPos, HULL_MIN, HULL_MAX, MASK_PLAYERSOLID_BRUSHONLY)
    return traceResult
end

-- Checks if the ground is stable at a given position.
local function isGroundStable(position)
    local groundTraceStart = position + Vector3(0, 0, 5)
    local groundTraceEnd = position + Vector3(0, 0, -67)
    local groundTraceResult = engine.TraceLine(groundTraceStart, groundTraceEnd, MASK_PLAYERSOLID_BRUSHONLY)
    return groundTraceResult.fraction < 1
end

-- Main function to check if the path between the current position and the node is walkable.
function Navigation.isWalkable(startPos, endPos)
    local direction = (endPos - startPos):Normalized()
    local totalDistance = (endPos - startPos):Length()
    local stepSize = math.max(MIN_STEP_SIZE, totalDistance / preferredSteps)
    local currentPosition = startPos
    local distanceCovered = 0

    while distanceCovered < totalDistance do
        stepSize = math.min(stepSize, totalDistance - distanceCovered)
        local nextPosition = currentPosition + direction * stepSize

        -- Check if the next step is clear
        local pathClearResult = isPathClear(currentPosition, nextPosition)
        if pathClearResult.fraction < 1 then
            -- We'll collide, get end position of the trace
            local collisionPosition = pathClearResult.endpos
            local groundNormal = pathClearResult.plane
            local angleBetween = math.deg(math.acos(groundNormal:Dot(Vector3(0, 0, 1))))

            if angleBetween <= MAX_SLOPE_ANGLE then
                -- Slope is climbable
                currentPosition = collisionPosition
            else
                -- Slope is too steep, try to step up
                local stepUpPosition = collisionPosition + Vector3(0, 0, STEP_HEIGHT)
                if isPathClear(currentPosition, stepUpPosition).fraction == 1 and isGroundStable(stepUpPosition) then
                    currentPosition = stepUpPosition
                else
                    -- Try to jump
                    local jumpPosition = currentPosition + Vector3(0, 0, JUMP_HEIGHT) + direction * 1
                    if isPathClear(currentPosition, jumpPosition).fraction == 1 and isGroundStable(jumpPosition) then
                        currentPosition = jumpPosition
                    else
                        return false -- Path is blocked
                    end
                end
            end
        else
            currentPosition = nextPosition
        end

        -- Check if the ground is stable
        if not isGroundStable(currentPosition) then
            -- Simulate falling
            local fallDistance = (stepSize / 450) * GRAVITY
            currentPosition = currentPosition - Vector3(0, 0, fallDistance)
        else
            -- Adjust direction to align with the ground
            local groundNormal = getGroundNormal(currentPosition)
            direction = adjustDirectionToGround(direction, groundNormal)
        end

        distanceCovered = distanceCovered + stepSize
    end

    return true -- Path is walkable
end


function Navigation.OptimizePath()
    local path = G.Navigation.path
    if not path then return end

    local currentIndex = G.Navigation.FirstAgentNode
    local checkingIndex = G.Navigation.SecondAgentNode
    local currentNode = G.Navigation.currentNode -- Assuming this is correctly set somewhere in your game logic
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
    local cYaw = pCmd:GetViewAngles().yaw
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
            --data
            pos = Vector3(cX, cY, cZ),
            id = area.id,
            c = area.connections,
            --corners
            nw = area.north_west,
            se = area.south_east,
            ne = Vector3(0,0,0),
            sw = Vector3(0,0,0),
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
    Navigation.SetNodes(navNodes) --alocate all ndoes to raw nodes cache and dynamic nodes.
    Navigation.FixAllNodes() --fix the dynamic
    Log:Info("Parsed %d areas from nav file.", #navNodes)
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

-- Perform a trace line down from a given height to check ground position
---@param startPos table The start position of the trace
---@param endPos table The end position of the trace
---@return boolean Whether the trace line reaches the ground at the target position
local function canTraceDown(startPos, endPos)
    local traceResult = engine.TraceLine(Vector3(startPos.x, startPos.y, startPos.z), Vector3(endPos.x, endPos.y, endPos.z), TRACE_MASK)
    return traceResult.fraction == 1
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

                -- If both conditions are met, perform a trace down check
                if horizontalCheck == 1 and verticalCheck == 1 then
                    local startPos = { x = node.pos.x, y = node.pos.y, z = node.pos.z + 72 }
                    local endPos = { x = conNode.pos.x, y = conNode.pos.y, z = conNode.pos.z }
                    local traceDownCheck = canTraceDown(startPos, endPos)

                    if traceDownCheck then
                        table.insert(adjacentNodes, conNode)
                    end
                end
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

    local horizontalDistance = math.abs(goalNode.pos.x - startNode.pos.x) + math.abs(goalNode.pos.y - startNode.pos.y)
    local verticalDistance = math.abs(goalNode.pos.z - startNode.pos.z)

    if (horizontalDistance <= 100 and verticalDistance <= 18) then --attempt to avoid work
        G.Navigation.path = {goalNode}
    elseif (horizontalDistance <= 700 and verticalDistance <= 18) or Navigation.isWalkable(startNode, goalNode) then --didnt work try doing less work
        G.Navigation.path = AStar.QuickPath(startNode, goalNode, G.Navigation.nodes, GetAdjacentNodes)
    else --damn it then do it propertly at least
        G.Navigation.path = AStar.Path(startNode, goalNode, G.Navigation.nodes, GetAdjacentNodes)
    end

    if not G.Navigation.path or #G.Navigation.path == 0 then
        Log:Error("Failed to find path from %d to %d!", startNode.id, goalNode.id)
        G.Navigation.path = nil
    else
        Log:Info("Path found from %d to %d with %d nodes", startNode.id, goalNode.id, #G.Navigation.path)
    end
end

return Navigation