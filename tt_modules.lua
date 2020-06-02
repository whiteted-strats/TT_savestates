require "Utilities\\GE\\ObjectDataReader"
require "Utilities\\GE\\GuardDataReader"
require "Data\\GE\\GameData"
require "Data\\GE\\PositionData"
require "Data\\GE\\PlayerData"
require "HUD_Matt\\HUD_Matt_lib"    -- vector ops	

-- Script module is separate - all modules probably should be
require "script_module"

local objectsByType = {}
local doorsByPreset = {}
local tilesByRoom = {}
local tilesByName = {}
local guardsById = {}
local playerDataFollower = {
    ["pos"] = {["x"] = 0, ["y"] = 0, ["z"] = 0},
    ["room"] = -1,
}

GUARD_ACTION_DYING = 0x4
GUARD_ACTION_FADING = 0x5

GUARD_ACTION_MOVING = 0xF

-- UNUSED atm
GUARD_ACTION_HURTING = 0x6
GUARD_ACTION_SIDESTEPPING = 0xB
GUARD_ACTION_FLEE = 0xD
GUARD_ACTION_LOOK_AROUND = 0x12
GUARD_ACTION_PULL_GRENADE = 0x14


-- Fetch all the objects by type
local function processObj(odr)
    local t = odr.current_data.type
    if objectsByType[t] == nil then
        objectsByType[t] = {}
    end

    table.insert(objectsByType[t], odr.current_address)
end
ObjectDataReader.for_each(processObj)

-- Process doors by preset
for _, doorAddr in ipairs(objectsByType[DoorData.type]) do
    doorsByPreset[DoorData:get_value(doorAddr, "preset") + 0x2710] = doorAddr
end

-- Process tiles by room & name
for _, tileAddr in ipairs(TileData.getAllTiles()) do
    local room = TileData:get_value(tileAddr, "room")
    local name = ("%06x"):format(TileData:get_value(tileAddr, "name"))
    if (tilesByRoom[room] == nil) then
        tilesByRoom[room] = {}
    end
    table.insert(tilesByRoom[room], tileAddr)
    tilesByName[name] = tileAddr
end

local function processGuard(gdr)
    guardsById[gdr:get_value("id")] = gdr.current_address
end
GuardDataReader.for_each(processGuard)


local function findCollision(vector, boundary)
    local rtn = -1

    for _, ln in ipairs(boundary) do
        -- Boundary line AB, player movement XY
        local pv = vectorSubtract(vector[2], vector[1])
        local dv = vectorSubtract(ln[1], vector[1])
        local bv = vectorSubtract(ln[2], ln[1])
        bv.y = 0
        local normal = {}
        normal.z = bv.x
        normal.x = -bv.z
        normal.y = 0
        bv.y = 0
        dv.y = 0
        if (normal.x ~= 0 or normal.z ~= 0) then  -- Ignore vertical lines
            local k = dotProduct(dv, normal) / dotProduct(pv, normal)   -- division by 0 okay
            -- Now A.n = (plrPrev + k*(plrVector)).n, so this is in the line
            -- If k in [0,1], we intersected the *infinite* line in this step
            -- We test if we entered the line segment
            if (0 < k and k <= 1) then
                local sectPnt = vectorAdd(vector[1], scaleVector(pv, k))
                local r = dotProduct(vectorSubtract(sectPnt, ln[1]), bv) / dotProduct(bv,bv)
                if (0 <= r and r <= 1) then
                    assert(rtn == -1, "Intersected multiple boundary lines")
                    rtn = k
                end
            end
        end
    end

    return rtn
end

local function updatePlayerDataFollower(playerPos, playerRoom)
    -- Note that if we run 2 achieved_ats using this, the 1st will use up the player movement
    playerDataFollower["pos"] = playerPos
    playerDataFollower["room"] = playerRoom
end




-- BEGIN achieved_at funcs (EXPORTS)
-- Some rely on being run each frame

local function boolToAchievedTime(b)
    if b then
        return GameData.get_mission_time()
    else
        return -1
    end
end

function door_open_achieved_at(params)
    local preset = params[1]

    assert(doorsByPreset[preset] ~= nil, ("Door with preset %04x not found"):format(preset))
    return boolToAchievedTime(DoorData:get_value(doorsByPreset[preset], "state") == 1)
end

function room_entry_achieved_at(params)
    -- Get the new player position
    -- Since we run every frame, we won't miss the player's step
    local playerPos = PlayerData.get_position()
    local playerRoom = TileData:get_value(PlayerData.get_tile() - 0x80000000, "room")
    local delta = GameData.get_global_timer_delta()
    local room = params[1]

    -- If we've just entered the room (weren't in it previously)
    if (playerRoom == room and playerDataFollower["room"] ~= room) then
        assert(tilesByRoom[room] ~= nil, ("Room with id 0x%02x has no tiles"):format(room))

        -- Get all the boundary lines
        local function isExternal(tileAddr)
            return TileData:get_value(tileAddr, "room") ~= room
        end

        local boundary = TileData.getBoundary(tilesByRoom[room], isExternal)

        local k = findCollision({playerDataFollower["pos"], playerPos}, boundary)
        assert(k ~= -1, ("Player crossed into room 0x%02x without crossing a boundary"):format(room))
        
        updatePlayerDataFollower(playerPos, playerRoom)  -- Update here (though this is optional)..
        local m = GameData.get_mission_time()
        return m - (1-k)*delta
    end

    updatePlayerDataFollower(playerPos, playerRoom)  -- and here
    return -1
end

local function tile_name_asserts(name)
    assert(type(name) == "string", "Tile names must be hex strings")
    assert(name:len() == 6, "Tile names must be 6 letters long")
    assert(tilesByName[name:lower()] ~= nil, "No tile found with name '" .. name:lower() .. "'")
end

function boundary_crossed_achieved_at(params)
    local playerPos = PlayerData.get_position()
    local playerRoom = TileData:get_value(PlayerData.get_tile() - 0x80000000, "room")
    
    A_TileNames = params[1]
    B_TileNames = params[2]

    -- Parse the args in a list and 'set' of tile addresses. Give nice name error messages
    A_Tiles = {}
    is_B_tile = {}
    for _, name in ipairs(A_TileNames) do
        tile_name_asserts(name)
        name = name:lower()
        table.insert(A_Tiles, tilesByName[name])
    end

    for _, name in ipairs(B_TileNames) do
        tile_name_asserts(name)
        name = name:lower()
        is_B_tile[tilesByName[name]] = true
    end

    local function isExternal(tileAddr)
        return is_B_tile[tileAddr]
    end
    local boundary = TileData.getBoundary(A_Tiles, isExternal)
    local k = findCollision({playerDataFollower["pos"], playerPos}, boundary)

    updatePlayerDataFollower(playerPos, playerRoom)  -- Update follower regardless

    if (k == -1) then
        return -1
    else
        return GameData.get_mission_time() - (1-k)*GameData.get_global_timer_delta()
    end
end

local function checkGuardID(guardId)
    assert(guardsById[guardId] ~= nil, ("No guard with ID 0x%02x found"):format(guardId))
end

function guard_kill_achieved_at(params)
    local guardId = params[1]
    local fade = params[2] == true  -- optional, default false
    local action

    checkGuardID(guardId)

    if (fade) then
        action = GUARD_ACTION_FADING
    else
        action = GUARD_ACTION_DYING
    end

    return boolToAchievedTime(GuardData:get_value(guardsById[guardId], "current_action") == action)
end

function guard_moving_achieved_at(params)
    local guardId = params[1]
    checkGuardID(guardId)
    return boolToAchievedTime(GuardData:get_value(guardsById[guardId], "current_action") == GUARD_ACTION_MOVING)
end

function guard_faded_achieved_at(params)
    local guardId = params[1]
    checkGuardID(guardId)

    return boolToAchievedTime(GuardData.is_empty(guardsById[guardId]))
end

function pad_targeted_achieved_at(params)
    local guardId = params[1]
    local pad = params[2]

    checkGuardID(guardId)
    
    return boolToAchievedTime(GuardData:get_value(guardsById[guardId], "2328_preset") == pad)
end

function pad_near_achieved_at(params)
    local actor = params[1]
    local pad = params[2]
    local posData

    if actor == "player" then
        posData = PlayerData.get_value("position_data_pointer") - 0x80000000
    else
        checkGuardID(actor)
        posData = GuardData:get_value(guardsById[actor], "position_data_pointer") - 0x80000000
    end

    local nearPad = PositionData.getNearPad(posData)

    return boolToAchievedTime(nearPad == pad)
end

function flag_set_achieved_at(params)
    local flag = params[1]
    assert( flag ~= 0 and bit.band(bit.bnot(flag - 1), flag) == flag , "Flag parameter must have a single bit set" )

    local setFlags = memory.read_u32_be(0x030978)
    return boolToAchievedTime(bit.band(setFlags, flag) ~= 0)
end