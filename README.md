# automata v.0.0.3
### A minetest mod for growing various cellular automata, including conway's game of life...

## Installation
like any minetest mod just install the mod as "automata" in your mods folder

## What it Does
### 2 Node types, 1 Tool

This mod provides a "Programmable" Cellular Automata block (Inactive Cell) which you place, then you select the Remote Control tool and punch it to bring up the activation form. Once activated, Inactive Cells become Active Cells and start growing according to the rules you've set. Active Cells turn into Inactive Cells when dug. None of these have crafting recipes at this time since this is sort of obviously a creative mode mod... Cells coming from nothing...

### The Rules Form
"Using" the Remote will bring up a form, this form can be left blank to default to Conway's Game of Life rules. Otherwise custom rules can be entered in "code" in the survival/birth format, for example, conway cells are 8 neighbors, rule 23/3 which means if there are 3 neighbors an empty cell turns on, and already-active cells stay on if they have two or three neighbors, otherwise they turn off. (there are many online collections of Game of Life entities: http://www.argentum.freeserve.co.uk/lex.htm )

Remember that zero is a valid option (for survival at least, not birth -- in this version) so that single nodes will grow with rules like n=4, 01234/14. The rest of the form fields have defaults, but if set allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

### Mode 1, activating inactive cells you have placed in the map:
When you hit "Activate" all inactive cells you have placed will start growing (this option will be missing if no inactive cells have been placed).

### Mode 2, activating a single node at your current location
When you hit "Single" a single cell will be placed at your current location and the rules you have filled out will be applied. This means the cell will die unless it has a zero in the survival rules: 0xx/xxx eg, 01234/14

### Mode 3, importing a Game of Life entitry from the supplied .LIF collection
Alternatively you can select a Game of Life pattern from the right-hand list. Double clicking will give a description. Some of these patterns are extremely large and are actually more like huge machines made of smaller patterns set in precise relation to eachother. Clicking "Import" will create the selected pattern, with the selected rules, relative to your current location. (Most of these patterns are intended for standard Conway 23/3 rules but some are intended for variations on these rules. If that is the case the alternate rules, or any you have entered, will be used.)

## Known Issues
Leaving the game leaves all active and inactive automata cells in the map dormant forever. Persistence will be in a future release.

## Next Steps in Development
- improve the form:
-- select boxes instead of text fields
-- more validation for neighbor / rule combinations, repeated numbers in the code, break code into two fields
-- field for conversion of NKS codes to readable codes
-- buttons for presets and /or a list of previously used rules
-- list of currently running patterns, pausing of patterns, saving pattern current state to schem
-- way to import saved schems or use //set or //mix (worldedit isn't running on_construct)
-- set pattern destructiveness (will eat into existing blocks or not)

- improve efficiency, use LVM (already tracking pmin and pmax)

- need a way to persist after quit/crash: need to save some tables to file on update, reload and reactivate at mod load

-new automata types:
-- 3D automata, which just amounts to more neighbors and higher rule codes.
-- rules for 2D automata which check for specific neighbor positions (non-totalistic)
-- 1D automata (Elementary Automata) (will need a form field for axis, add rules for 2n)
-- support of Moore and von Neumann neighborhoods (diamonds) of more than 1 unit distance and 3D implementations (n-depth)
-- an anti-cell which could be used to implement 0-neighbor birth rules within defined game fields/volumes (or not)

##New since v.0.0.2
- menu for creating Game of Life entities from a library of .lif files at current location

##New since v.0.0.1
- multiple cell activation solved with Remote Control
- eliminated all but two node types, active and inactive
- eliminated reliance on minetest.register_abm, node metadata
- eliminated use of NKS codes, now using 3/23 format
- patterns operate in all planes
- patterns can grow in either direction at any distance per iteration, or stay in plane
- efficiency greatly improved, started maintaining pmin and pmax
- much improved rule form and form validation

## screenshots

"Single" mode

![screenshot_2030436717](https://cloud.githubusercontent.com/assets/12679496/8044135/0b4ec964-0de8-11e5-9cc1-8a2c93e6fc1a.png)

![screenshot_2030482649](https://cloud.githubusercontent.com/assets/12679496/8044134/0b4c0a26-0de8-11e5-9b83-f38f1bfd6476.png)

"Import" mode

![screenshot_2030594267](https://cloud.githubusercontent.com/assets/12679496/8044137/0b579940-0de8-11e5-84d0-54588b532047.png)

![screenshot_2030616024](https://cloud.githubusercontent.com/assets/12679496/8044138/0b5d4340-0de8-11e5-8b84-6fe2a224337a.png)

"Activate" mode

![screenshot_2030738253](https://cloud.githubusercontent.com/assets/12679496/8044136/0b51f01c-0de8-11e5-84cf-36615741fc4b.png)

![screenshot_2030806016](https://cloud.githubusercontent.com/assets/12679496/8044139/0b643b1e-0de8-11e5-95df-e494ee3f5cbb.png)

