-- Function to perform a deep copy of a table
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Define the G module
local G = {}

G.Menu = {
    Tabs = {
        Main = true,
        Settings = false,
        Visuals = false,
        Movement = false,
    },

    Main = {
        Enable = true,
        Skip_Nodes = true, --skips nodes if it can go directly to ones closer to target.
        Optymise_Path = true,--straighten the nodes into segments so you would go in straight line
        OptimizationLimit = 20, --how many nodes ahead to optymise
        shouldfindhealth = true, -- Path to health
        SelfHealTreshold = 45, -- Health percentage to start looking for healthPacks
        smoothFactor = 0.05
    },
    Visuals = {
        EnableVisuals = true,
        memoryUsage = true,
        drawNodes = false, -- Draws all nodes on the map
        drawPath = true, -- Draws the path to the current goal
        drawCurrentNode = false, -- Draws the current node
    },
    Movement = {
        lookatpath = false, -- Look at where we are walking
        smoothLookAtPath = true, -- Set this to true to enable smooth look at path
        Smart_Jump = true, -- jumps perfectly before obstacle to be at peek of jump height when at colision point
    }
}

G.Default = {
    entity = nil,
    index = 1,
    team = 1,
    Class = 1,
    AbsOrigin = Vector3{0, 0, 0},
    OnGround = true,
    ViewAngles = EulerAngles{0, 0, 0},
    Viewheight = Vector3{0, 0, 75},
    VisPos = Vector3{0, 0, 75},
    vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82)}
}

G.pLocal = G.Default

G.World_Default = {
    players = {},
    healthPacks = {},  -- Stores positions of health packs
    spawns = {},       -- Stores positions of spawn points
    payloads = {},     -- Stores payload entities in payload maps
    flags = {},        -- Stores flag entities in CTF maps (implicitly included in the logic)
}

G.World = G.World_Default

G.Gui = {
    IsVisible = false,
    CritHackKey = gui.GetValue("Crit Hack Key")
}

G.Misc = {
    jumptimer = 0,
    NodeTouchDistance = 7,
    NodeTouchHeight = 82,
    workLimit = 1,
}

G.Navigation = {
    path = {},
    rawNodes = {},
    nodes = {},
    currentNode = nil,
    currentNodePos = Vector3(0, 0, 0),
    currentNodeID = 1,
    currentNodeTicks = 0,
    FirstAgentNode = 1,
    SecondAgentNode = 2,
}

function G.ReloadNodes()
    G.Navigation.nodes = G.Navigation.rawNodes
end

G.Tasks = table.readOnly {
    None = 0,
    Objective = 1,
    Health = 2,
    Follow = 3,
    Medic = 4,
    Goto = 5,
}

G.Current_Tasks = {}
G.Current_Task = G.Tasks.Objective

G.Benchmark = {
    MemUsage = 0
}

-- Store initial state
local G_initial = deepCopy(G)

-- Function to reset G to initial state
function G:Reset()
    for k, v in pairs(G_initial) do
        self[k] = deepCopy(v)
    end
end

return G