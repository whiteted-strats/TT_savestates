## Target time (tt) savestate manager version 0.0

### Requirements

Requires the Data_and_Utilities folders, and an active movie & level.

### Description

Allows you to write simple scripts such as frig_agent_2.3_tt.lua, which specify various checkpoints throughout the level based (currently) on either player position, doors, or guards. It is the TAS equivalent of my SplitsROM.

Parameters for checkpoints are really easy to find using the setup editor (https://github.com/carnivoroussociety/GoldEditor). See the example.

### Features

When you reach a checkpoint, the computed split is compared to your best so far. If it is an improvement then the state is saved to a folder alongside your current movie.

Successive best checkpoints are also saved to a "carousel" of numbered savestate slots. In the example I instruct it to use {7,8,9}, so for example the 5th checkpoint will be saved to slot 8 (5 % 3 = 2).

Your best splits are stored in 'decl.txt' in this folder.

### Structure

tt_savestates.lua contains the main code.

tt_modules.lua contains all module code together atm (it's not too much)


### Other files

frig_agent_19_decl.txt contains the splits from running this on my agent 19 TAS ( https://www.youtube.com/watch?v=972hg-gOgdA ).

### Future

In the future it'll give more "advice" i.e. 
* consider how much you've built fullspeed / (strafe) momentum
* tell you when you are in range of a door, but aren't facing & pressing b

Also I'll add more features (modules) for other levels. Peering into script state is probably quite a big one. In the frigate agent 2.3 example, this is implicit in the "Hostage run" split, since this is the hostage's script responding to the guard finishing fading.