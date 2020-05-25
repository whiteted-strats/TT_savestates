require "tt_savestates"

tt_init()

setupCarousel({8,9})
add_checkpoint("On deck", "enter_room", {0x33,})
add_checkpoint("Past wall", "enter_room", {0x34,})
add_checkpoint("1st door", "open_door", {0x2755,})
add_checkpoint("Early corridor", "cross_boundary", {{"058F10", "05B110"}, {"05B210", "059310"}})
add_checkpoint("Mid corridor", "enter_room", {0x08,})
add_checkpoint("2nd door", "open_door", {0x2758,})
add_checkpoint("Taker kill", "kill_guard", {0x0F,})
add_checkpoint("Taker fade", "kill_guard", {0x0F,true})
add_checkpoint("Taker faded", "faded_guard", {0x0F})
add_checkpoint("Hostage run", "moving_guard", {0x30})
add_checkpoint("Outside", "enter_room", {0x34,})
add_checkpoint("Ramp approach", "enter_room", {0x32,})

