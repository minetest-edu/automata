# automata
### minetest mod for growing various cellular automata, including conway's game of life

I will be adding more rules and patterns as time permits. the codes used are from:
https://www.wolframscience.com/nksonline/page-173

## installation
like any minetest mod just install the mod as "automata" in your mods folder

## configuration

settings in init.lua worth knowing about:
<pre>
GEN_LIMIT = 30 --change the number of iterations allowed
DEAD_CELL = "default:dirt" -- can be set to "air"
FINAL_CELL = "default:mese" -- sometimes nice to do "default:mese", otherwise MUST be set to DEAD_CELL
VERT = 1 -- could be set to -1 for downward, 1 for upward or 0 for flat (Flat is not tested)
</pre>
## plans for future revisions:

1. get VERT = 0 working. currently this is buggy so automata must leave behind dead coral and grow either up or down
2. get different planes working, so that automata can grow sideways, 
3. handle the up/down/flat (and orientation as per #2) in a form or some other way so it can be set without editing mod
4. set up some schems or even a crafting form for initial Game of Life starting states and critters, as per: http://www.radicaleye.com/lifepage/picgloss/picgloss.html
5. instead of multiple new automata nodes for each new rule, have a single node with a right-click action which sets the rules in a form
6. trigger the node with a punch rather than it starting automatically
7. improve the queue system, uniquely identify each automata as it grows (improve collisions)
8. add different materials in order to emulate a 3D system of interacting material cells such as in the android game PixieDust: https://play.google.com/store/apps/details?id=org.neotech.app.pixiedust&hl=en

## screenshots

code 942 growing up 30 iterations

![screenshot_1282617618](https://cloud.githubusercontent.com/assets/12679496/7900620/6c8abb4e-0720-11e5-98f0-a99914cabc81.png)

create a glider with worldedit (for now)

![glider](https://cloud.githubusercontent.com/assets/12679496/7900624/97340aa8-0720-11e5-900b-024698d6b732.png)

glider growing

![screenshot_1282818807](https://cloud.githubusercontent.com/assets/12679496/7900621/71aa9c34-0720-11e5-8c5a-1e9e3e59e7c4.png)

create a random field using worldedit

![random_field](https://cloud.githubusercontent.com/assets/12679496/7900627/a23e7168-0720-11e5-9175-b736eced2f81.png)

random field of conway life growing upward

![screenshot_1282996956](https://cloud.githubusercontent.com/assets/12679496/7900629/b73e2f18-0720-11e5-9739-53e0222f33be.png)

conway blinker growing up

![screenshot_1283636384](https://cloud.githubusercontent.com/assets/12679496/7900631/d8214120-0720-11e5-96c8-4fc648dc46b4.png)

code 942 growing down (started in space with worldedit)

![screenshot_1283373396](https://cloud.githubusercontent.com/assets/12679496/7900632/e475fbf0-0720-11e5-97e1-205afa946526.png)

code 942 growing down, from below

![screenshot_1283277162](https://cloud.githubusercontent.com/assets/12679496/7900633/fff075a4-0720-11e5-8b5c-3d4b90e9039c.png)

random collided growths (growth becomes irregular when you leave the area and return) with FINAL_CELL set to mese

![screenshot_1284125787](https://cloud.githubusercontent.com/assets/12679496/7900635/1cdb513e-0721-11e5-8a6e-25d3ad439e8c.png)
