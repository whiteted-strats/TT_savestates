require "Data\\GE\\GameData"
require "Data\\GE\\PlayerData"
require "Utilities\\GE\\ObjectDataReader"

camerasByPreset = {}
function foreach(odr)
    if odr.current_data.type == 0x06 then   -- camera data
        camerasByPreset[odr:get_value("preset")] = odr:get_value("position_data_pointer")
    end
end
ObjectDataReader.for_each(foreach)


-- posDataPtr = 0x8006AAD8
-- objName = "Frig helicopter"

S2_CAM_PRESETS = {0x2750, 0x274E, 0x274D, 0x2752}
s2_cam_no = {}
for i, preset in ipairs(S2_CAM_PRESETS) do
    s2_cam_no[camerasByPreset[preset]] = i
end

while true do
    local stop = mainmemory.read_u32_be(0x071df0)
    local start = 0x80071620
    local count = (stop - start) / 4
    
    --gui.drawText(15,10, count .. " items on screen.")

    -- Mark all 4 cameras as offscreen
    local onscreen = {false, false, false, false}
    local pdp, camNo

    -- Walk the on-screen list, and note all cams
    for i=start,(stop-4),4 do
        pdp = mainmemory.read_u32_be(i - 0x80000000)
        camNo = s2_cam_no[pdp]
        if camNo ~= nil then
            onscreen[camNo] = true
        end
    end

    -- Display which cams are on-screen
    local y = 0
    for i, os in ipairs(onscreen) do
        y = y + 15
        if os then
            gui.drawText(15,y, "[+] Cam #" .. i .. " ON-SCREEN")
        else
            gui.drawText(15,y, "    Cam #" .. i .. " off-screen")
        end
    end
    
    emu.frameadvance()
end

