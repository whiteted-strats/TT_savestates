-- Example user script

require "tt_savestates"
tt_init()   -- first

-- Use slots 7,8,9 as well as named states to save successive best checkpoints
-- Omit the call or pass {} if you don't want to use it
setupCarousel({7,8,9})

-- Enter_room takes the room ID.
-- Click on the level background in the setup editor's "edit objects" mode to see the room ID
add_checkpoint("On deck", "enter_room", {0x33,})
add_checkpoint("Past wall", "enter_room", {0x34,})

-- Open_door takes the door's preset
-- This will always be 27XY, X != 0
-- Select the door (an object) to read out the preset from the setup editor
add_checkpoint("1st door", "open_door", {0x2755,})

-- Cross_boundary takes 2 lists of tile names.
-- In "edit clipping" mode, the name is the first item when a tile is selected
add_checkpoint("Early corridor", "cross_boundary", {{"058F10", "05B110"}, {"05B210", "059310"}})
add_checkpoint("Mid corridor", "enter_room", {0x08,})
add_checkpoint("2nd door", "open_door", {0x2758,})

-- Kill_guard takes the guard ID, and a boolean defaulting to false.
--   If false, the checkpoint is at the moment of the killing shot / slap
--   If true, it is at the end of the death animation, start of the fade
-- Select a guard in the setup editor using "edit objects" mode to see the ID. It's not the "guard number"
add_checkpoint("Taker kill", "kill_guard", {0x0F,})
add_checkpoint("Taker fade", "kill_guard", {0x0F,true})

-- Taker_faded is the next step, after the guard has finished fading.
add_checkpoint("Taker faded", "faded_guard", {0x0F})

-- Moving_guard also takes just a guard ID, and triggers when a guard starts moving (not along a fixed path / 'patrol')
add_checkpoint("Hostage run", "moving_guard", {0x30})

add_checkpoint("Outside", "enter_room", {0x34,})
add_checkpoint("Ramp approach", "enter_room", {0x32,})

