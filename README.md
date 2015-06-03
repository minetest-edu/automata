# automata
### A minetest mod for growing various cellular automata, including conway's game of life...

This mod adds two new blocks (at time of writing):
1. Programmable block (good for automata that will grow from a single block)
2. Conway's Game of Life Block (buggy but workable)

## Installation
like any minetest mod just install the mod as "automata" in your mods folder
optionally copy the schems folder to the world folder (only if you have worldedit installed)

## What it Does
there is no configuration to speak of since now this mod provides a "Programmable" block which you place and then fill out the form.
The form requires a code (as per Wolfram's NKS system, see: https://www.wolframscience.com/nksonline/page-173)

The rest of the form fields are optional and have defaults, but allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

For the purposes of experimentation another node-type, automata:conway is included for quick placing of Conway Game of Life blocks and adding blocks near currently growing Conway objects.

## Known Issues

1. Really only single-node automata are worth playing with until we figure out a triggering mechanism for multi-cell automata. The "conway" block is the only multi-block automata that will work at this time. We need to develop a way of triggering groups of cells.

2. Worldedit schema files work as a way to bring in multiple cells at a time, but only if the metadata in the .we file is properly filled out, since propagation of cells is done via metadata, and worldedit-placed blocks do not use on_construct() so that default fields don't get filled. That means you have to create a shape with stone or some other block, then //save the schema, then manually edit the schema (using search and replace) to be the correct node type and have the correct metadata. A worldedit schema file example (a glider) is included in the schems folder which should be copied to the world folder.



## Next Steps in Development
- improve the form to be less manual, selecting growth and neighbor codes, directions, and node types from a list
- add options to the form to control whether the automata will be destructive to other blocks
- figure out how to import blocks from worldedit with metadata filled out.
- figure out a triggering mechanism for groups of blocks simultaneously (applies to 1D and 3D automata as well).
- set up a library of schems or deploying Game of Life starting states and critters, as per: http://www.radicaleye.com/lifepage/picgloss/picgloss.html
- improve efficiency, currently counting neighbors, might be a more efficient method using minetest api calls or voxelmanip
- find a way for the automata pattern not to break when the player gets too far from part of it
- add 3D automata, which just amounts to more neighbors and higher rule codes.
- add rules for 2D automata which check for specific neighbor positions (non-totalistic)
- add 1D automata (Elementary Automata)
- add support of Moore and von Neumann neighborhoods (diamonds) of more than 1 unit distance and 3D implementations
- add an anti-cell which could be used to implement 0-neighbor birth rules within defined game fields/volumes
- 

## screenshots (may be out of date but give you an idea)

code 942 growing up 30 iterations

![screenshot_1282617618](https://cloud.githubusercontent.com/assets/12679496/7900620/6c8abb4e-0720-11e5-98f0-a99914cabc81.png)

create a glider with worldedit (for now)

![glider](https://cloud.githubusercontent.com/assets/12679496/7900624/97340aa8-0720-11e5-900b-024698d6b732.png)

glider growing

![screenshot_1282818807](https://cloud.githubusercontent.com/assets/12679496/7900621/71aa9c34-0720-11e5-8c5a-1e9e3e59e7c4.png)

create a random field using worldedit -- doesn't currently work

![random_field](https://cloud.githubusercontent.com/assets/12679496/7900627/a23e7168-0720-11e5-9175-b736eced2f81.png)

random field of conway life growing upward doesn't currently work

![screenshot_1282996956](https://cloud.githubusercontent.com/assets/12679496/7900629/b73e2f18-0720-11e5-9739-53e0222f33be.png)

conway blinker growing up this works if you place the three blocks in rapid succession

![screenshot_1283636384](https://cloud.githubusercontent.com/assets/12679496/7900631/d8214120-0720-11e5-96c8-4fc648dc46b4.png)

code 942 growing down

![screenshot_1283373396](https://cloud.githubusercontent.com/assets/12679496/7900632/e475fbf0-0720-11e5-97e1-205afa946526.png)

code 942 growing down, from below

![screenshot_1283277162](https://cloud.githubusercontent.com/assets/12679496/7900633/fff075a4-0720-11e5-8b5c-3d4b90e9039c.png)

random collided growths (growth becomes irregular when you leave the area and return) with the "final" field set to default:mese

![screenshot_1284125787](https://cloud.githubusercontent.com/assets/12679496/7900635/1cdb513e-0721-11e5-8a6e-25d3ad439e8c.png)
