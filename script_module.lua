require "Data\\GE\\ScriptData"
require "Utilities\\GE\\GuardDataReader"
require "Data\\GE\\GameData"

-- Repeated from tt_modules
local guardsById = {}
local function processGuard(gdr)
    guardsById[gdr:get_value("id")] = gdr.current_address
end
GuardDataReader.for_each(processGuard)


local function getCommandLength(scriptPtr)
    local id = memory.read_u8(scriptPtr)
    if (id == 0xAD) then
        -- Comment, variable length
        local i = 1
        while (memory.read_u8(scriptPtr + i) ~= 0) do
            i = i + 1
        end
        return 1 + i
    else
        -- All simple functions of the form
        -- 03e00008     jr ra
        -- 2402XXXX     li v0, X    (addiu v0, zero, X)
        local funcAddr = memory.read_u32_be(0x052100 + 4*id)
        -- 7F virtual -> physical on the ROM
        funcAddr = funcAddr + 0x34b30 - 0x7f000000
        memory.usememorydomain("ROM")
        local instr1 = memory.read_u32_be(funcAddr)
        local instr2 = memory.read_u32_be(funcAddr + 0x4)
        memory.usememorydomain("RDRAM") -- switch back

        assert(instr1 == 0x03e00008)
        assert(bit.rshift(instr2, 16) == 0x2402)
        return bit.band(instr2,0xFFFF)
    end
end

local function findYields(scriptPtr)
    -- Returns pointers to the START of yield statements
    local id = -1
    local len
    local yieldOffsets = {}
    local scriptBase = scriptPtr
    while (id ~= 0x4) do
        id = memory.read_u8(scriptPtr)
        len = getCommandLength(scriptPtr)

        if (id == 0x3) then
            table.insert(yieldOffsets, scriptPtr - scriptBase)
        end

        scriptPtr = scriptPtr + len
    end

    return yieldOffsets
end

local function loadScriptPositions(scriptPtr)
    local yields = findYields(scriptPtr)
    local posMap = {}
    posMap[0] = 0
    for i, yieldStart in ipairs(yields) do
        posMap[yieldStart + 1] = i  -- Point to after the yield
    end
    return posMap
end

local scriptID = {} -- map (virtual) addr -> name for the level scripts
local scriptPositions = {} -- map name -> offset -> [0,1,..)
local levelScriptPseudoID = {} -- map level script name -> "guard" "ID" 
local levelScriptCount = 0

local function getScriptData(scriptBlob)
    local addr, name
    while true do
        addr = memory.read_u32_be(scriptBlob)
        id = memory.read_u32_be(scriptBlob + 0x4)
        scriptBlob = scriptBlob + 8
        if (addr == 0) then -- omits 0011, but we can't track that anyway
            break
        end

        --console.log(("%04X : %08X"):format(id, addr))

        scriptID[addr] = id
        scriptPositions[id] = loadScriptPositions(addr - 0x80000000)
    
        -- Level script
        if (bit.rshift(id,8) == 0x10) then
            levelScriptPseudoID[id] = levelScriptCount
            levelScriptCount = levelScriptCount + 1
        end

    end
end
getScriptData(memory.read_u32_be(0x75D14) - 0x80000000) -- Level scripts & Actors (10XX & 04XX)
getScriptData(0x03744C) -- All globals, 00XX


-- EXPORTS

local function commonSuffix(data, actorAddr, targetID, targetPos)
    local currScriptAddr = data:get_value(actorAddr, "action_block_pointer")
    local currScriptOffset = data:get_value(actorAddr, "action_block_offset")

    -- Convert to current script ID and yield position
    local currScriptID = scriptID[currScriptAddr]
    local currScriptPos = scriptPositions[currScriptID][currScriptOffset]

    -- Return if there's a match
    if currScriptID == targetID and currScriptPos == targetPos then
        return GameData.get_mission_time()
    else
        return -1
    end
end

function level_script_position_achieved_at(params)
    -- Script actor starting with script [1] is at yield [2] in script [3]
    --   [3] defaults to [1] if omitted
    -- E.G. on cradle call (0x1003, 1, 0x040E) for a checkpoint which detects the start of the "Trev at Location F" script

    -- Read params
    local scriptActor = params[1]
    local targetYieldPos = params[2]
    local targetScriptID = params[1]    -- default
    if (table.getn(params) > 2) then
        targetScriptID = params[3]
        assert(levelScriptPseudoID[targetScriptID] ~= nil, string.format("No such level script %X", scriptID))
    end
    assert(levelScriptPseudoID[scriptActor] ~= nil, string.format("No such level script %X", scriptActor))

    -- Find the script actor's data : script addr & offset
    local sdAddr = ScriptData.get_start_address() + ScriptData.size * levelScriptPseudoID[scriptActor]
    
    return commonSuffix(ScriptData, sdAddr, targetScriptID, targetYieldPos)
end

function guard_script_position_achieved_at(params)
    local id = params[1]
    local targetYieldPos = params[2]
    local targetScriptID = params[3]    -- all 3 params required

    local guardAddr = guardsById[id]
    if guardAddr == nil then
        return -1
    end

    return commonSuffix(GuardData, guardAddr, targetScriptID, targetYieldPos)
end
