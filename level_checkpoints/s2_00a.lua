require "tt_savestates"
tt_init()   -- first

-- Standard
setupCarousel({7,8,9})

CAM_1_PRESET = 0x2750
CAM_2_PRESET = 0x274E
CAM_3_PRESET = 0x274D
CAM_4_PRESET = 0x2752


add_checkpoint("first_corner", "enter_room", {0x13,})
--add_checkpoint("guard_05_spawned", "guard_spawn", {0x05,})  -- we may not want him to spawn asap we need to check. 
add_checkpoint("GRENADE_1", "guard_nade", {0x05, true,})    -- spawning guard
add_checkpoint("long_straight", "enter_room", {0x05,})  -- boundary is slanted
add_checkpoint("past_hut", "enter_room", {0x07,})  -- boundary is perfect
add_checkpoint("approaching_bump", "enter_room", {0x0B,})
add_checkpoint("near_compound", "enter_room", {0x0A,})  -- boundary is convex
add_checkpoint("destroyed_cam_2", "destroy_object", {CAM_2_PRESET,})
add_checkpoint("near_tower", "enter_room", {0x0C,})  -- boundary is good, in the middle of the dip
add_checkpoint("after_tower", "enter_room", {0x0D,})
add_checkpoint("near_end", "cross_boundary", {{"042300", "042600"}, {"042200", "042500"}}) -- probably before we want to throw
add_checkpoint("final_door", "open_door", {0x2716,})
add_checkpoint("inside", "enter_room", {0x27,})

