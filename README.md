# automata v.0.0.4
### A minetest mod for growing various cellular automata, including conway's game of life...

## Installation
like any minetest mod just install the mod as "automata" in your mods folder

## What it Does
### 2 Node types, 1 Tool

This mod provides a "Programmable" Cellular Automata block (Inactive Cell) which you place, then you select the Remote Control tool and punch it to bring up the activation form. Once activated, Inactive Cells become Active Cells and start growing according to the rules you've set. Active Cells turn into Inactive Cells when dug. None of these have crafting recipes at this time since this is sort of obviously a creative mode mod... Cells coming from nothing...

### The Rules Form
"Using" the Remote will bring up a form, this form can be left blank to default to Conway's Game of Life rules. Otherwise custom rules can be entered in "code" in the survival/birth format, for example, conway cells are 8 neighbors, rule 23/3 which means if there are 3 neighbors an empty cell turns on, and already-active cells stay on if they have two or three neighbors, otherwise they turn off. (there are many online collections of Game of Life entities: http://www.argentum.freeserve.co.uk/lex.htm )

Remember that zero is a valid option (for survival at least, not birth -- in this version it is ignored) so that single nodes will grow with rules like n=4, 01234/14. The rest of the form fields also have defaults, but if set allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

1D automata follow the NKS "rules" as per: http://www.wolframscience.com/nksonline/page-53 . They also require an additional parameter for the calculation axis, obviously the growth axis and calculation axis can't be the same. 2D automata only need the growth axis set, even if growth is set to zero, because the calculation plane is implied by the growth axis (perpendicular to it). 3D automata actually have less options since their growth and calculation directions are all axis. For automata to grow properly, their trail should either be set to air, or they need to be set to "destructive" so that any trail they leave doesn't impede their natural growth in a later iteration.

The remote now has a "Manage" tab which allows you to see your own patterns and pause or resume them. Exporting from that tab is soon to come.

### Mode 1, activating inactive cells you have placed in the map:
When you hit "Activate" all inactive cells you have placed will start growing (this option will be missing if no inactive cells have been placed).

### Mode 2, activating a single node at your current location
When you hit "Single" a single cell will be placed at your current location and the rules you have filled out will be applied. This means the cell will die unless it has a zero in the survival rules: 0xx/xxx eg, 01234/14

### Mode 3, importing a Game of Life entity from the supplied .LIF collection
Alternatively you can select a Game of Life pattern from the right-hand list. Double clicking will give a description. Some of these patterns are extremely large and are actually more like huge machines made of smaller patterns set in precise relation to eachother. Clicking "Import" will create the selected pattern, with the selected rules, relative to your current location. (Most of these patterns are intended for standard Conway 23/3 rules but some are intended for variations on these rules. If that is the case the alternate rules, or any you have entered, will be used.)

## Known Issues
- Leaving the game leaves all active and inactive automata cells in the map dormant forever. Persistence will be in a future release.

## Next Steps in Development
- improve the form:
    - field for conversion of NKS codes to readable codes
    - buttons for presets and /or a list of previously used rules
    - way to import saved schems or use //set or //mix (worldedit isn't running on_construct)
	- an "Admin" tab visible to players with the 'automata' priv to modify default settings

-new automata types:
    - rules for 2D and 3D automata which check for specific neighbor positions (non-totalistic)
    - support of Moore and von Neumann neighborhoods (diamonds) of more than 1 unit distance and 3D implementations (n-depth)
    - an anti-cell which could be used to implement 0-neighbor birth rules within defined extent (or not)
- other improvements
    - improve efficiency, use LVM especially for 3D patterns
	- allow 1D patterns to grow faster otherwise they are a little boring
    - need a way to persist/resume after quit/crash: need to save some tables to file on update, reload and reactivate at mod load

For other known issues and planned improvements see: https://github.com/bobombolo/automata/issues
	
##New since v.0.0.3
- improved form with management tab, better validation, persistence
- 1D automata introduced
- 3D automata introduced
- ability to start a single-cell automata of any type at player's current position
- "Manage" tab allows monitoring of your patterns, including pausing and resuming
- patterns can be set to be destructive or respect the environment


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

1D Automata (uses NKS rules 0-255)

![screenshot_168002977](https://cloud.githubusercontent.com/assets/12679496/8142078/10ec421c-112f-11e5-9c46-6388101ee623.png)

3D Automata

![screenshot_168375193](https://cloud.githubusercontent.com/assets/12679496/8142096/e20f3642-112f-11e5-91c4-b7dde4739dec.png)

"Manage" tab

![screenshot_168492531](https://cloud.githubusercontent.com/assets/12679496/8142097/e210c25a-112f-11e5-9136-56ad3a99bb97.png)