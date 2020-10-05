require "Data\\GE\\PositionData"
require "HUD_Matt\\HUD_matt_core"
require "HUD_Matt\\HUD_matt_lib"

require "Utilities\\GE\\ObjectDataReader"
require "Data\\GE\\ObjectData"

-- 0x1EB248,    -- '1st' cam
-- 0x1EB14C,    -- compound cam
-- 0x1EB050,    -- motorbike hut cam
-- 0x1EB344,    -- satellite building cam

objAddrs = {
    0x1EADB0, -- Right radio
    0x1EAE40, -- Middle monitor
    0x1EAD20, -- Left radio
    0x1EB430, -- Box
}

alpha = 0xFF

-- Table is drawn seperately
tableData = {
    objAddr = 0x1EAB90,
}
tableColour = alpha * 0x1000000 + 0xFFFF00 -- yellow


-- =====================================================================

-- Expecting this to be called like (1,1,1), (1,-1,1) to get the corners of a (bounding) box
-- scaleStructure is 6 floats, -x, +x, -y, +y, -z, +z
local function getCorner(data, x,y,z)
    x = mainmemory.readfloat(data.scalesPointer + 2 + 2*x, true)
    y = mainmemory.readfloat(data.scalesPointer + 10 + 2*y, true)
    z = mainmemory.readfloat(data.scalesPointer + 18 + 2*z, true)

    local loc = applyHomMatrix({x=x, y=y, z=z}, data.T)
    return vectorAdd(data.pos, loc)
end

-- =====================================================================


local datas = {}

for i, objAddr in ipairs(objAddrs) do
    local data = {
        objAddr = objAddr,
        T = nil,
        pos = nil,
        scalesPointer = nil,
    }
    table.insert(datas, data)
end


local colourful = {0xFFFF0000, 0xFF00BB00, 0xFF0000FF}
local colourless = {0xFF884444, 0xFF448844, 0xFF444488}
local colour = colourful

-- Apply alpha
for i=1,3,1 do
    colour[i] = colour[i] % 0x1000000 + alpha * 0x1000000
end

local onscreen = {}

function updateData(data)
    -- Transform at 0x18 - rotation and scale
    data.T = matrixFromMainMemory(data.objAddr+0x18)
    data.pos = PhysicalObjectData:get_value(data.objAddr, "position")
    data.pdp = PhysicalObjectData:get_value(data.objAddr, "position_data_pointer")
    data.onscreen = onscreen[data.pdp]

    -- Um:
    local mdp = mainmemory.read_u32_be(data.objAddr + 0x14) - 0x80000000 -- reading 1EADC4
    local a = mainmemory.read_u32_be(mdp + 0x8) - 0x80000000 -- reading 1F7308
    local b = mainmemory.read_u32_be(a) - 0x80000000 -- reading 037DF0
    local c = mainmemory.read_u32_be(b + 0x14) - 0x80000000 -- reading 206A40
    local d = mainmemory.read_u32_be(c + 0x4) - 0x80000000 -- reading 206A48

    data.scalesPointer = d + 4
end

function updateT()
    -- Update the onscreen list
    local stop = mainmemory.read_u32_be(0x071df0)
    local start = 0x80071620
    onscreen = {}
    for i=start,(stop-4),4 do
        pdp = mainmemory.read_u32_be(i - 0x80000000)
        onscreen[pdp] = true
    end

    for _, data in ipairs(datas) do
        updateData(data)
    end

    -- Table
    updateData(tableData)
end


-- Draw lines between the faces of the console to make a box
function linkFaces()
    local ls = {}

    for _, data in ipairs(datas) do
        
        local xs = {1,1,-1,-1}
        local ys = {1,-1,-1,1}

        for i = 1,4,1 do
            local cornerA = getCorner(data, xs[i], ys[i], -1)
            local cornerB = getCorner(data, xs[i], ys[i], 1)

            local lnObj = {}
            lnObj.ps = { cornerA, cornerB }
            lnObj.colour = colour[3]

            if data.onscreen then
                table.insert(ls, lnObj)
            end
        end
    end

    return ls
end


function drawFaces()
    local ps = {}
    local zs = {-1, 1}
    local xs = {1,1,-1,-1}
    local ys = {1,-1,-1,1}
    
    for _, data in ipairs(datas) do
        for j = 1,2,1 do
            local ply = {}
            ply.colour=colour[j] -- red bottom, green top

            local vs = {}

            for i = 1,4,1 do
                table.insert(vs, getCorner(data, xs[i], ys[i], zs[j]))
            end

            ply.ps = vs

            if data.onscreen then   -- only add if on screen
                table.insert(ps, ply)
            end
        end
    end

    -- =================================================
    -- Draw the table top and 2 sides
    local top = {}
    local left = {}
    local right = {}
    local back = {}
    for i = 1,4,1 do
        table.insert(top, getCorner(tableData, xs[i], 1, ys[i]))
        table.insert(left, getCorner(tableData, -1, xs[i], ys[i]))
        table.insert(right, getCorner(tableData, 1, xs[i], ys[i]))
        table.insert(back, getCorner(tableData, xs[i], ys[i], -1))
    end
    -- Don't show all of the backboard though..
    local m = 0.75
    back[2].y = m*back[2].y + (1-m)*back[1].y
    back[3].y = m*back[3].y + (1-m)*back[4].y

    if tableData.onscreen then
        table.insert(ps,  {colour=tableColour, ps = top,})
        table.insert(ps,  {colour=tableColour, ps = left,})
        table.insert(ps,  {colour=tableColour, ps = right,})
        table.insert(ps,  {colour=tableColour, ps = back,})
    end

    -- =================================================


    return ps
end


showHUD(updateT, nil, linkFaces, drawFaces, nil)











