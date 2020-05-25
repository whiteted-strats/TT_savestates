require "tt_modules"

-- STATE variables
local fullDirc = ""
local shortDirc = ""
local carouselSlots = {}
local checkpoints = {}  -- .name, .type(name), .params, .earliest
local verbose = true

local prevCheckpointI = 0

-- Minor
local indexForName = {}
local declEarliest = {}

-- Checkpoint types, each offering
--  .achieved(params)
--      returning the theoretical frame which we reached it at, or -1 if we haven't reached it
--      the params will come from our checkpoint.params
--      stateless, and only needs to say achieved for 1 frame
-- This is a map name -> Type
local checkpointType = {
    ["open_door"] = {["achieved"] = door_open_achieved_at},
    ["enter_room"] = {["achieved"] = room_entry_achieved_at},
    ["cross_boundary"] = {["achieved"] = boundary_crossed_achieved_at},
    ["kill_guard"] = {["achieved"] = guard_kill_achieved_at},
    ["moving_guard"] = {["achieved"] = guard_moving_achieved_at},
    ["faded_guard"] = {["achieved"] = guard_faded_achieved_at},
}

-- TODO use gui.addMessage
-- TODO add various checkpoint types

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end

function setupTTfolder()
    local fn = movie.filename()
    if (fn == "") then
        console.log("[-] No movie active. Exiting")
        return
    end

    local noext = fn:sub(1,fn:len()-4)  -- Remove .bk2
    local rev = noext:reverse()
    local stemLen = rev:find("\\") - 1
    shortDirc = "TT_STATES_" .. noext:sub(noext:len() - stemLen + 1)
    fullDirc = noext:sub(1,noext:len() - stemLen) .. shortDirc

    local cmd = "mkdir \"" .. fullDirc .. "\""
    console.log("> " .. cmd)
    os.execute(cmd)

    -- Load the earliest splits
    declEarliest = {}
    if file_exists(fullDirc .. "\\decl.txt") then
        console.log("Loading declared splits..")
        for ln in io.lines(fullDirc .. "\\decl.txt") do
            local i = ln:find(" : ")
            if (i ~= nil) then
                declEarliest[ln:sub(1,i-1)] = tonumber(ln:sub(i+3))
            end
        end
    end

end

function setupCarousel(slots)
    for _, slot in ipairs(slots) do
        if (slot < 0 or slot > 9) then
            console.log("[-] Slots must be between 0 and 9 inclusive")
            return
        end
    end

    carouselSlots = slots
end

function add_checkpoint(name, typename, params)
    assert(name:find(" : ") == nil, "checkpoint name must not contain ' : '")

    local checkpoint = {}
    checkpoint.earliest = declEarliest[name]    -- may be nil
    checkpoint.name = name
    checkpoint.params = params
    checkpoint.type = checkpointType[typename]

    assert(checkpoint.type ~= nil, "Checkpoint type '" .. typename .. "' unrecognised")

    table.insert(checkpoints, checkpoint)
    indexForName[name] = table.getn(checkpoints)

    assert(checkpoints[indexForName[name]].name == name)
end

function setVerbose(v)
    verbose = v
end
-- f(msg) if verbose, else nada
local function ifv(f, msg)
    if verbose then
        f(msg)
    end
end

local function saveTTstate(name)
    local i = indexForName[name]
    assert(i ~= nil)

    ifv(console.write, "Saved to ")

    -- Save to carousel
    local cLen = table.getn(carouselSlots)
    if (cLen > 0) then
        local slot = carouselSlots[((i-1) % cLen) + 1]  -- 1-based crap
        savestate.saveslot(slot)
        ifv(console.write, "[" .. slot .. "] & ")
    end

    -- Save to the TT folder
    local path = "\\" .. name .. ".bk2"
    savestate.save(fullDirc .. path)
    ifv(console.writeline, shortDirc .. path)
end

local function saveDecls()
    -- Save the new declared times
    -- Keep the names that we've read out of the file,
    --   in case we've removed a checkpoint which we'll want to add back later

    for _, checkpoint in ipairs(checkpoints) do
        declEarliest[checkpoint.name] = checkpoint.earliest -- must be atleast as low
    end

    file = io.open(fullDirc .. "\\decl.txt", "w") -- overwrite
    for name, frame in pairs(declEarliest) do
        file:write(name .. " : " .. frame .. "\n")
    end
    file:close()
end

local function onLoadState()
    -- The user will certainly save using other savestates,
    -- But they can't have passed checkpoints without our script realising, and setting userdata
    -- We don't store the actual index for robustness : the list could change
    local name = userdata.get("TT_checkpoint_name")
    if (name == nil) then
        prevCheckpointI = 0
        return
    end

    prevCheckpointI = indexForName[name]
    assert(prevCheckpointI ~= nil, "Loaded state with unrecognised checkpoint name '" .. name .. "'")

end

local function onFrameEnd()
    --gui.drawText(10, 10, "Prev checkpoint index = " .. prevCheckpointI)
    if (prevCheckpointI >= table.getn(checkpoints)) then
        -- No more checkpoints
        return
    end

    -- Test the next checkpoint
    local checkpoint = checkpoints[prevCheckpointI + 1]
    local frame = checkpoint.type.achieved(checkpoint.params)

    if (frame == -1) then
        return
    end

    -- If we've reached it..

    -- Set userdata to be saved with the state .. if say the player saves state
    -- We need to store the name since we won't be told it by event.onloadstate
    userdata.set("TT_checkpoint_name", checkpoint.name)
    prevCheckpointI = prevCheckpointI + 1

    if (checkpoint.earliest == nil) then
        -- First record
        console.log("Initial record for checkpoint [" .. prevCheckpointI .. "] '" .. checkpoint.name .. ("' set as %.2f"):format(frame))

    elseif (frame + 0.0001 < checkpoint.earliest) then
        console.log("New record for checkpoint [" .. prevCheckpointI .. "] '" .. checkpoint.name .. ("' of %.2f  <  %.2f"):format(frame, checkpoint.earliest))

    else
        console.log("Reached checkpoint [" .. prevCheckpointI .. "] '" .. checkpoint.name .. ("' at %.2f  >=  %.2f"):format(frame, checkpoint.earliest))
        return
    end

    -- Save state, and also update the file of declared best splits.
    checkpoint.earliest = frame
    saveTTstate(checkpoint.name)
    saveDecls()
end

function tt_init()
    -- Call before setting the checkpoints

    checkpoints = {}

    -- There doesn't seem to be an 'on movie start' event for us to use,
    --   so start the script after loading the movie.
    setupTTfolder()

    while event.unregisterbyname("TT_loadstate") do
        --
    end
    while event.unregisterbyname("TT_frameend") do
        --
    end
    while event.unregisterbyname("TT_exit") do
        --
    end

    event.onloadstate(onLoadState, "TT_loadstate")
    event.onframeend(onFrameEnd, "TT_frameend")

    -- Treat this as a load state - unless we haven't started yet
    --   This is because it's important to provide some way to reset the userdata
    if GameData.get_mission_time() == 0 then
        prevCheckpointI = 0
        userdata.set("TT_checkpoint_name", nil)
    else
        onLoadState()
    end
end