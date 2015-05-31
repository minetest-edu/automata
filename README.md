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
