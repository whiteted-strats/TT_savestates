require "tt_savestates"
tt_init()   -- first

-- Standard
setupCarousel({7,8,9})


add_checkpoint("1st_door", "open_door", {0x2721,})
add_checkpoint("2nd_door", "open_door", {0x2718,})
add_checkpoint("on_stairs", "enter_room", {0x12,})
-- [Not optimised - stairs before boris hands]
local borisID = 0x19
add_checkpoint("boris_hands", "progressed_guard_script", {borisID, 2, 0x0408})

-- After a 3s timer provided we're close & looking nearby
add_checkpoint("bond_speech", "progressed_guard_script", {borisID, 5, 0x0408})
-- Once we're outside of 50 units
add_checkpoint("boris_flees", "progressed_guard_script", {borisID, 3, 0x0408})

-- Initial important Boris pathing
add_checkpoint("boris_targets_centre", "target_pad", {borisID, 0x47})
add_checkpoint("player_controlling", "near_pad", {"player", 0x4A})
add_checkpoint("boris_t_42", "target_pad", {borisID, 0x42})

-- Boris' early route
add_checkpoint("boris_t_3D", "target_pad", {borisID, 0x3D})
add_checkpoint("boris_t_51", "target_pad", {borisID, 0x51})
add_checkpoint("boris_t_50", "target_pad", {borisID, 0x50})
add_checkpoint("boris_t_4F", "target_pad", {borisID, 0x4F}) -- not turning left

-- The player needs to stay out of the set until Boris targets 4F,
--   and then needs to enter the set before Boris reaches 4F
add_checkpoint("player_in_set_05", "near_pad", {"player", 0x51})

add_checkpoint("boris_right_turn", "target_pad", {borisID, 0x4D})
--add_checkpoint("boris_between_doors", "target_pad", {borisID, 0x52})

-- Ending now
add_checkpoint("boris_stopped", "progressed_guard_script", {borisID, 1, 0x0408})    -- Look at him / be close
add_checkpoint("boris_hands_2", "progressed_guard_script", {borisID, 2, 0x0408})    -- Sees dead guard / bullet near / hear since last yield / bond in sight
-- [Drive Boris forward with a butt shot during this]
add_checkpoint("bond_speech_2", "progressed_guard_script", {borisID, 5, 0x0408})    -- After 3s
-- [Walks to pad, proceed when within]
-- => true TAS won't walk at all!
-- => won't need an extra shot to end the animation provided we can get some slight right turn to him (boris go left of lured guard)
--  (and if the animation goes far enough) - may need 2?
add_checkpoint("disable_the_security", "progressed_guard_script", {borisID, 6, 0x0408})


-- 1002's structure should allow for a slightly buffered press
add_checkpoint("computer_activated", "set_flag", {0x00000100,})
add_checkpoint("leave_mainframe_room", "enter_room", {0x9,})
add_checkpoint("big_room", "enter_room", {0x6,})
add_checkpoint("final_stairs", "enter_room", {0x3,})
add_checkpoint("final_door", "open_door", {0x2716,})