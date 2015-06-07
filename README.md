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

![screenshot_1907736976](https://cloud.githubusercontent.com/assets/12679496/8023523/2dbb2b7c-0ccc-11e5-987c-96a8e3472966.png)

![screenshot_1907864008](https://cloud.githubusercontent.com/assets/12679496/8023522/2db88502-0ccc-11e5-9978-9a55003d790e.png)

![screenshot_1907912113](https://cloud.githubusercontent.com/assets/12679496/8023524/2dc2b4e6-0ccc-11e5-9e07-04959e47b350.png)

![screenshot_1908036072](https://cloud.githubusercontent.com/assets/12679496/8023525/2dc4ff08-0ccc-11e5-8912-251568a7ec82.png)

![screenshot_1908137241](https://cloud.githubusercontent.com/assets/12679496/8023528/2dd0614a-0ccc-11e5-8574-23618fdd6b94.png)

![screenshot_1908195426](https://cloud.githubusercontent.com/assets/12679496/8023526/2dc70514-0ccc-11e5-9a21-400ccf680d3f.png)

![screenshot_1908293278](https://cloud.githubusercontent.com/assets/12679496/8023527/2dcf94c2-0ccc-11e5-9992-b3ad5f71dbf5.png)

![screenshot_1908744383](https://cloud.githubusercontent.com/assets/12679496/8023529/2dd52108-0ccc-11e5-97fa-079e3c144bba.png)

![screenshot_1283373396](https://cloud.githubusercontent.com/assets/12679496/7900632/e475fbf0-0720-11e5-97e1-205afa946526.png)

![screenshot_1282818807](https://cloud.githubusercontent.com/assets/12679496/7900621/71aa9c34-0720-11e5-8c5a-1e9e3e59e7c4.png)

