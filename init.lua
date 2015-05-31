nks = {}
GEN_LIMIT = 30
DEAD_CELL = "default:dirt" -- can be set to "air"
FINAL_CELL = DEAD_CELL -- sometimes nice to do "default:mese", otherwise MUST be set to DEAD_CELL
VERT = 1 -- could be set to -1 for downward, 1 for upward or 0 for flat
CHAT_DEBUG = false

local rules = {
	corners = false, -- defaults to 4 neighbors only, true means 8 neighbors
	--the following rules are either false for disabled, true for any, or a table with specific values
	survive = true, -- number of neighbors required to perpetuate the active cell, survive true implues death false
					-- the vacancies in the survive list imply the death list, also survive false implies death true
	birth   = false, -- number of neighbors required for birth from an empty cell
}

-- need a queue so that grown nodes don't get immediately also assessed for growth,
-- automata need to be assessed a layer at a time, not according to whatever scan order is used by MT
nks.block_queue = {}
nks.check_list = {}

--rulecheck, simple in_array type function
local function rule_check(value, list)
	for k,v in pairs(list) do
		if v == value then return true end
	end
	return false
end

--simple generation retrieval for limiting growth
local function get_gen(pos)
	local meta = minetest.get_meta(pos)
	local gen = meta:get_int("gen")
	return gen
end

--simple generation setting for limiting growth
local function set_gen(pos, gen)
	local meta = minetest.get_meta(pos)
	local gen = meta:set_int("gen", gen)
	return true
end

-- function to add nodes to the iteration queue
local function enqueue(pos, nodename, gen)
	--test for gen limit
	if GEN_LIMIT >= gen then
		local pos = minetest.pos_to_string(pos)
		if FINAL_CELL ~= nil and GEN_LIMIT == gen then nodename = FINAL_CELL end
		--checks to see if the block is already enqueued to change
		if nks.block_queue[pos] == nil then
			if nodename ~= "air" then nks.block_queue[pos] = {nodename = nodename, gen = gen}
			else nks.block_queue[pos] = {nodename = nodename, gen = nil}
			end
			if CHAT_DEBUG then minetest.chat_send_all(nodename.." node enqueued at "..pos) end
		end
	end
end

-- function to execute the queued commands
function nks:dequeue()
	--if #nks.block_queue > 0 then
		--loop through each entry, keyed by pos with value opts.nodename, opts.gen
		for k,v in pairs(nks.block_queue) do
			local pos = minetest.string_to_pos(k)
			minetest.set_node(pos, {name = v.nodename})
			set_gen(pos,v.gen)
			if CHAT_DEBUG then minetest.chat_send_all("set a gen "..v.gen.." "..v.nodename.." at ("..k..")") end
			-- remove the just executed row
			nks.block_queue[k] = nil
			-- remove the check_list entry as well so the space can be alive again for other gens/nodes
			nks.check_list[k] = nil -- also necessary for VERT = 0 mode
		end
	--end
end

-- then we will use globalstep to execute the queue
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 5 then
		-- process the queue
		nks:dequeue()
		--reset the check_list need to find a better place to flush this... some kind of gen check
		--nks.check_list = {}
		timer = 0
	end
end)

--returns a list of positions which are neighbors to a pos on a given y plane
local function list_neighbors(pos, corners)
	local list = {}
	list.n  = {x=pos.x,  y=pos.y,z=pos.z+1}
	list.e  = {x=pos.x+1,y=pos.y,z=pos.z}
	list.s  = {x=pos.x,  y=pos.y,z=pos.z-1}
	list.w  = {x=pos.x-1,y=pos.y,z=pos.z}
	if corners == true then
		list.ne = {x=pos.x+1,y=pos.y,z=pos.z+1}
		list.se = {x=pos.x+1,y=pos.y,z=pos.z-1}
		list.sw = {x=pos.x-1,y=pos.y,z=pos.z-1}
		list.nw = {x=pos.x-1,y=pos.y,z=pos.z+1}
	end
	return list
end

-- list non-same neighbors
local function list_inactive_neighbors(pos, nodename, corners)
	local all_neighbors = list_neighbors(pos, corners)
	local non_active_neighbors = {}
	for k,v in pairs(all_neighbors) do
		local testnode = minetest.get_node(v)
		if (testnode.name ~= nodename) then
			table.insert(non_active_neighbors, v)
		end
	end
	return non_active_neighbors
end

-- this is a quick count of cardinal neighbors for a given node
local function count_same_neighbors(pos, nodename, corners)
	local c = 0
	local neighbors = list_neighbors(pos, corners)
	for k,v in pairs(neighbors) do
		local testnode = minetest.get_node(v)
		if (testnode.name == nodename) then
			c = c+1
		end
	end
	-- mark the node as checked (@todo: mark by which gen and node type)
	nks.check_list[minetest.pos_to_string(pos)] = true
	--minetest.log("action", "checked " .. minetest.pos_to_string(pos))
	return c
end

--the main growth function for all rulesets
local function grow(pos, node, rules)
	
	--first off, have we inspected this active cell yet? if so bail on grow()
	if nks.check_list[minetest.pos_to_string(pos)] ~= nil then 
		return false 
	end
	
	--load the generation metadata
	local gen = get_gen(pos)
	
	--check to see if we automatically perpetuate self
	if rules.survive ~= false and type(rules.survive) ~= "table" then 
		minetest.chat_send_all("straightup") --REMOVE
		enqueue({x=pos.x, y=pos.y+VERT, z=pos.z}, node.name, gen+1)
		nks.check_list[minetest.pos_to_string(pos)] = true -- mark this node as checked
		--enqueue this cell to turn off unless VERT = 0
		if VERT ~= 0 then
			enqueue(pos, DEAD_CELL, gen)
		end
	elseif type(rules.survive) == "table" then 
		local active_count = count_same_neighbors(pos, node.name, rules.corners) -- this will mark node as checked
		if rule_check(active_count, rules.survive) then
			enqueue({x=pos.x, y=pos.y+VERT, z=pos.z}, node.name, gen+1)
			--enqueue this cell to turn off unless VERT = 0
			if VERT ~= 0 then
				enqueue(pos, DEAD_CELL, gen)
			end
		else
			-- survival check fails then DEATH is implied, in which case we don't perpetuate	
			-- enqueue this cell to turn off if VERT = 0
			if VERT ~= 0 then
				enqueue(pos, DEAD_CELL, gen)
			else
				--if VERT = 0 then we have to explicitly make a hole with air,
				-- @todo, record original node type for resetting, which will allow CA to pass through materials
				enqueue(pos, "air", gen)
				
			end
		end
	elseif rules.survive == false then
		--death implied, just as above where survival check fails @todo remove this duplication of code
		-- we don't perpetuate but enqueue this cell to turn off if VERT = 0
		if VERT ~= 0 then
			enqueue(pos, DEAD_CELL, gen)
		else
			--if VERT = 0 then we have to explicitly make a hole with air,
			-- @todo, record original node type for resetting, which will allow CA to pass through materials
			enqueue(pos, "air", gen)
			
		end
	end
	
	--if BIRTH is enabled, we use this opportunity to check all non-active nieghbors
	--by the nature of this scan, we know there is at least one neighbor, so birth=true implies > 0
	if rules.birth ~= false then
		local inactive_neighbors = list_inactive_neighbors(pos, node.name, rules.corners)
		if type(rules.birth) ~= "table" then
			--minetest.chat_send_all(type(rules.birth)) --REMOVE
			-- birth=true means any amount of neighbors so we can just set it since this is a neighbor
			for k,v in pairs(inactive_neighbors) do
				--minetest.chat_send_all(k.." : " ..minetest.pos_to_string(v))
				if nks.check_list[minetest.pos_to_string(v)] == nil then
					enqueue({x=v.x,y=v.y+VERT,z=v.z}, node.name, gen+1)
					nks.check_list[minetest.pos_to_string(v)] = true
				end
			end
		else
			--if specific neighbor counts are listed in the rules we have to count neighbors and then apply a rule check
			for k,v in pairs(inactive_neighbors) do
				--minetest.chat_send_all(k.." : " ..minetest.pos_to_string(v))
				if nks.check_list[minetest.pos_to_string(v)] == nil then
					local cn = count_same_neighbors(v, node.name, rules.corners) --will mark the node as checked
					if rule_check(cn, rules.birth) then
						enqueue({x=v.x,y=v.y+VERT,z=v.z}, node.name, gen+1)
					end
				end
			end
		end
	end	
end

--dead_cells are for done layers
minetest.register_node("nks:dead_cell", {
	description = "Dead Cell",
	tiles = {"dead.png"},
	light_source = 2,
	groups = {oddly_breakable_by_hand=1},
})


-- NKS rule 1022 node
minetest.register_node("nks:rule_1022", {
	description = "NKS_1022",
	tiles = {"nks1022.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
})

-- NKS rule 1022 action
minetest.register_abm({
	nodenames = {"nks:rule_1022"},
	neighbors = {"air"}, --won't grow underground or underwater . . .
	interval = 4,
	chance = 1,
	action = function(pos, node)
		rules.corners  = false
		rules.surivive = true
		rules.birth    = true
		
		grow(pos, node, rules)
	end,
})

-- NKS rule 942 node
minetest.register_node("nks:rule_942", {
	description = "NKS_0942",
	tiles = {"nks942.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
})

-- NKS rule 942 action
minetest.register_abm({
	nodenames = {"nks:rule_942"},
	neighbors = {"air"}, --won't grow underground or underwater . . .
	interval = 4,
	chance = 1,
	action = function(pos, node)
		rules.corners  = false
		rules.surivive = true
		rules.birth    = {1,4}
		
		grow(pos, node, rules)
	end,
})
-- NKS rule Conway node
minetest.register_node("nks:conway", {
	description = "Game of Life",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
})

-- NKS rule 942 action
minetest.register_abm({
	nodenames = {"nks:conway"},
	neighbors = {"air"}, --won't grow underground or underwater . . .
	interval = 4,
	chance = 1,
	action = function(pos, node)
		rules.corners = true
		rules.survive = {2, 3}
		rules.birth   = {3}
		grow(pos, node, rules)
	end,
})
