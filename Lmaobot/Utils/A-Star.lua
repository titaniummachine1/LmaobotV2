local Heap = require("Lmaobot.Utils.Heap")

---@alias PathNode { id : integer, x : number, y : number, z : number }

---@class AStar
local AStar = {}

local function ManhattanDistance(nodeA, nodeB)
    return math.abs(nodeB.pos.x - nodeA.pos.x) + math.abs(nodeB.pos.y - nodeA.pos.y)
end

local function HeuristicCostEstimate(nodeA, nodeB)
    return ManhattanDistance(nodeA, nodeB)
end

local function AStarPath(start, goal, nodes, adjacentFun)
    local openSet = Heap.new(function(a, b) return a.fScore < b.fScore end)
    local closedSet = {}
    local gScore, fScore = {}, {}
    gScore[start] = 0
    fScore[start] = HeuristicCostEstimate(start, goal)

    openSet:push({node = start, fScore = fScore[start], path = {start}})

    local function pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
        gScore[neighbor] = tentativeGScore
        local neighborFScore = tentativeGScore + HeuristicCostEstimate(neighbor, goal)
        fScore[neighbor] = neighborFScore

        local newPath = {table.unpack(currentPath)}
        newPath[#newPath + 1] = neighbor  -- Efficiently append to the path

        openSet:push({node = neighbor, fScore = neighborFScore, path = newPath})
    end

    while not openSet:empty() do
        local currentData = openSet:pop()
        local current = currentData.node
        local currentPath = currentData.path

        if current.id == goal.id then
            return currentPath
        end

        closedSet[current] = true

        for _, neighbor in ipairs(adjacentFun(current, nodes)) do
            if not closedSet[neighbor] then
                local tentativeGScore = gScore[current] + HeuristicCostEstimate(current, neighbor)

                if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
                    neighbor.previous = current
                    pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
                end
            end
        end
    end

    return nil -- Path not found if loop exits
end

AStar.Path = AStarPath

return AStar


--[[ 2
    
local Heap = require("Lmaobot.Utils.Heap")

---@alias PathNode { id : integer, x : number, y : number, z : number }

---@class AStar
local AStar = {}

local function ManhattanDistance(nodeA, nodeB)
    return math.abs(nodeB.pos.x - nodeA.pos.x) + math.abs(nodeB.pos.y - nodeA.pos.y)
end

local function HeuristicCostEstimate(nodeA, nodeB)
    return ManhattanDistance(nodeA, nodeB)
end

local function AStarPath(start, goal, nodes, adjacentFun)
    local openSet = Heap.new(function(a, b) return a.fScore < b.fScore end)
    local closedSet = {}
    local gScore, fScore = {}, {}
    gScore[start] = 0
    fScore[start] = HeuristicCostEstimate(start, goal)

    openSet:push({node = start, path = {start}, fScore = fScore[start]})

    local function pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
        gScore[neighbor] = tentativeGScore
        fScore[neighbor] = tentativeGScore + HeuristicCostEstimate(neighbor, goal)
        local newPath = {table.unpack(currentPath)}
        table.insert(newPath, neighbor)
        openSet:push({node = neighbor, path = newPath, fScore = fScore[neighbor]})
    end

    while not openSet:empty() do
        local currentData = openSet:pop()
        local current = currentData.node
        local currentPath = currentData.path

        if current.id == goal.id then
            local reversedPath = {}
            for i = #currentPath, 1, -1 do
                table.insert(reversedPath, currentPath[i])
            end
            return reversedPath
        end

        closedSet[current] = true

        local adjacentNodes = adjacentFun(current, nodes)
        for _, neighbor in ipairs(adjacentNodes) do
            if not closedSet[neighbor] then
                local tentativeGScore = gScore[current] + HeuristicCostEstimate(current, neighbor)

                if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
                    neighbor.previous = current
                    pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
                end
            end
        end
    end

    return nil -- Path not found if loop exits
end

AStar.Path = AStarPath

return AStar
]]

--------------------------------------------

--[[ 1
local Heap = require("Lmaobot.Utils.Heap")

---@alias PathNode { id : integer, x : number, y : number, z : number }

---@class AStar
local AStar = {}

local function ManhattanDistance(nodeA, nodeB)
    return math.abs(nodeB.pos.x - nodeA.pos.x) + math.abs(nodeB.pos.y - nodeA.pos.y)
end

local function HeuristicCostEstimate(nodeA, nodeB)
    return ManhattanDistance(nodeA, nodeB)
end

local function AStarPath(start, goal, nodes, adjacentFun)
    local openSet, closedSet = Heap.new(), {}
    local gScore, fScore = {}, {}
    gScore[start] = 0
    fScore[start] = HeuristicCostEstimate(start, goal)

    openSet.Compare = function(a, b) return fScore[a.node] < fScore[b.node] end
    openSet:push({node = start, path = {start}})

    local function pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
        gScore[neighbor] = tentativeGScore
        fScore[neighbor] = tentativeGScore + HeuristicCostEstimate(neighbor, goal)
        local newPath = {table.unpack(currentPath)}
        table.insert(newPath, neighbor)
        openSet:push({node = neighbor, path = newPath})
    end

    while not openSet:empty() do
        local currentData = openSet:pop()
        local current = currentData.node
        local currentPath = currentData.path

        if current.id == goal.id then
            local reversedPath = {}
            for i = #currentPath, 1, -1 do
                table.insert(reversedPath, currentPath[i])
            end
            return reversedPath
        end

        closedSet[current] = true

        local adjacentNodes = adjacentFun(current, nodes)
        for _, neighbor in ipairs(adjacentNodes) do
            local neighborNotInClosedSet = closedSet[neighbor] and 0 or 1
            local tentativeGScore = gScore[current] + HeuristicCostEstimate(current, neighbor)

            local newGScore = (not gScore[neighbor] and 1 or 0) + (tentativeGScore < (gScore[neighbor] or math.huge) and 1 or 0)
            local condition = neighborNotInClosedSet * newGScore

            if condition > 0 then
                pushToOpenSet(current, neighbor, currentPath, tentativeGScore)
            end
        end
    end

    return nil -- Path not found if loop exits
end

AStar.Path = AStarPath

return AStar]]