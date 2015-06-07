# automata v.0.0.2
### A minetest mod for growing various cellular automata, including conway's game of life...

## Installation
like any minetest mod just install the mod as "automata" in your mods folder

## What it Does
This mod provides a "Programmable" Cellular Automata blocks which you place, then you select the Remote Control tool and punch it to bring up the activation form.

This form can be left blank to default to Conway's Game of Life rules. Otherwise custom rules can be entered in "code" in the birth/survival format, for example, conway cells are rule 3/23 which means if there are 3 neighbors an empty cell turns on, and already-active cells stay on if they have two or three neighbors, otherwise they turn off. (there are many online collections of Game of Life entities: http://www.argentum.freeserve.co.uk/lex.htm )

Remember that zero is a valid option (for survival at least, not birth -- in this version) so that single nodes will grow with rules like n=4, 14/01234. The rest of the form fields have defaults, but if set allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

When you hit "activate" all inactive cells you have placed will start growing.

## Known Issues
Leaving the game leaves all active and inactive automata cells in the map dormant forever. Persistence will be in the next release.

## Next Steps in Development
- improve the form:
-- select boxes instead of text fields
-- more validation for neighbor / rule combinations, repeated numbers in the code, break code into two fields
-- field for conversion of NKS codes to readable codes
-- buttons for presets and /or a list of previously used rules
-- list of currently running patterns, pausing of patterns, saving pattern current state to schem
-- way to import saved schems or use //set or //mix (worldedit isn't running on_construct)
-- menu for creating Game of Life entities from a library of .lif files or other ascii collections
-- set pattern destructiveness (will eat into existing blocks or not)

- improve efficiency, use LVM (already tracking pmin and pmax)

- need a way to persist after quit/crash: need to save some tables to file on update, reload and reactivate at mod load

-new automata types:
-- 3D automata, which just amounts to more neighbors and higher rule codes.
-- rules for 2D automata which check for specific neighbor positions (non-totalistic)
-- 1D automata (Elementary Automata) (will need a form field for axis, add rules for 2n)
-- support of Moore and von Neumann neighborhoods (diamonds) of more than 1 unit distance and 3D implementations (n-depth)
-- an anti-cell which could be used to implement 0-neighbor birth rules within defined game fields/volumes (or not)

##New since v.0.0.1
- multiple cell activation solved with Remote Control
- eliminated all but two node types, active and inactive
- eliminated reliance on minetest.register_abm, node metadata
- eliminated use of NKS codes, now using 3/23 format
- patterns operate in all planes
- patterns can grow in either direction at any distance per iteration, or stay in plane
- efficiency greatly improved, started maintaining pmin and pmax
- much improved rule form and form validation

## screenshots (may be out of date but give you an idea)
Programmable block form:
![screenshot_1536075142](https://cloud.githubusercontent.com/assets/12679496/7951709/423fb4e4-0968-11e5-881f-7a7f3cec1d73.png)

code 5n942 growing up 30 iterations

![screenshot_1282617618](https://cloud.githubusercontent.com/assets/12679496/7900620/6c8abb4e-0720-11e5-98f0-a99914cabc81.png)

create a glider with worldedit //load glider (for now)

![screenshot_1535971080](https://cloud.githubusercontent.com/assets/12679496/7951706/42327d92-0968-11e5-8043-f345c0b78491.png)

glider growing

![screenshot_1282818807](https://cloud.githubusercontent.com/assets/12679496/7900621/71aa9c34-0720-11e5-8c5a-1e9e3e59e7c4.png)

create a random field using worldedit -- doesn't currently work

![random_field](https://cloud.githubusercontent.com/assets/12679496/7900627/a23e7168-0720-11e5-9175-b736eced2f81.png)

random field of conway life growing upward -- doesn't currently work

![screenshot_1282996956](https://cloud.githubusercontent.com/assets/12679496/7900629/b73e2f18-0720-11e5-9739-53e0222f33be.png)

conway blinker growing up -- this works if you place the three blocks in rapid succession

![screenshot_1283636384](https://cloud.githubusercontent.com/assets/12679496/7900631/d8214120-0720-11e5-96c8-4fc648dc46b4.png)

code 5n942 growing down -- need a block in space to attach the Programmable block to though

![screenshot_1283373396](https://cloud.githubusercontent.com/assets/12679496/7900632/e475fbf0-0720-11e5-97e1-205afa946526.png)

code 5n942 growing down, from below

![screenshot_1283277162](https://cloud.githubusercontent.com/assets/12679496/7900633/fff075a4-0720-11e5-8b5c-3d4b90e9039c.png)

a 5n942 growing in the plane of x -- again attached to a node placed in space by worldedit

![screenshot_1537130594](https://cloud.githubusercontent.com/assets/12679496/7951910/9cb06a3e-096a-11e5-9e9f-bfbb201f3fef.png)

latest dev version

![screenshot_1898729268](https://cloud.githubusercontent.com/assets/12679496/8023190/605dbaa0-0cbc-11e5-9683-c71501f84025.png)

