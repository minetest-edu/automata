automata = {}
GEN_LIMIT = 20 --change the number of iterations allowed:
DEAD_CELL = "default:dirt" -- can be set to "air"
FINAL_CELL = "default:dirt" -- sometimes nice to do "default:mese", cannot be false
VERT = 1 -- could be set to -1 for downward, 1 for upward or 0 for flat
NORTH = 0
EAST = 0
CHAT_DEBUG = false

-- save and restore stuff taken from travelnet mod
-- TODO: save and restore ought to be library functions and not implemented in each individual mod!
-- called whenever a node is added on the fly

automata.save_node = function(nodename)
	
	local data=minetest.registered_nodes[nodename]
	if data then
		row = minetest.serialize({nodename = nodename, data = data})
		local path = minetest.get_worldpath().."/automata.data";
		local file = io.open( path, "a" );
		if( file ) then
			file:write( data );
			file:close();
		else
			minetest.log("error", "Savefile '"..tostring( path ).."' could not be written.");
		end
	else
		--if node not found something is wonky
		minetest.log("error", "tried to persist node "..nodename.." but couldn't find that node type")
		return false
	end
end

--called on mod load (see end of this file) to reload any node types created on the fly by activating a programmable automata node
automata.restore_data = function()

	local path = minetest.get_worldpath().."/automata.data";
	
	local file = io.open( path, "r" );
	if( file ) then
		--register each node
		for line in file:lines() do
			local row = minetest.deserialize(line)
			minetest.register_node(row[name],row[data])
		end
		file:close();
	else
		minetest.log("error", "Savefile '"..tostring( path ).."' not found.");
	end
end

-- function to convert integer to binary string
local function toBits(num, bits)
    -- returns a table of bits, most significant first.
    bits = bits or select(2,math.frexp(num))
    local t={} -- will contain the bits        
    for b=1,bits,1 do --left to right binary table
        t[b]=math.fmod(num,2)
        num=(num-t[b])/2
    end
    return t
end

local function nks_rule_convert(name)
	local rules = {}

	local bits = 0
	local corners = string.sub(name, 10, 11) --very important that the nodename starts with "automata:9n" or "automata:5n"
	-- the 5 or 9 neighbor type
	if corners == "5n" then
		bits = 10
		rules.corners = false
		--minetest.log("action", corners)
	elseif corners == "9n" then
		bits = 18
		rules.corners = true
		--minetest.log("action", corners)
	else 
		minetest.log("error", "node name not in correct format for nks_rule_convert()")
		return false
	end
	
	-- get the integer code from the nodename
	local code = string.sub(name, 12) --very important that the nodename continues with a code only, no trailing chars
	
	-- todo catch error from tonumber
	-- also we know that a 5n rule can be no larger than 1023, though a 9n rule can be less than 1024
	code = tonumber(code)
	--minetest.debug("action", "nodename= "..name)
	if (bits == 10 and code > 1023) or (bits == 18 and code > 262143) then 
		minetest.chat_send_all("improperly formatted code -- must be in the format 5n942")
		return false 
	end
	
	-- convert the integer code to a bigendian binary table
	local bintable = toBits(code, bits)
	--minetest.log("action", table.concat(bintable))
	
	-- test for survival rule 0, which cannot be implemented in this mod
	if bintable[1] == 1 then
		minetest.chat_send_all("odd-numbered codes are not supported")
		return false
	end
	-- test for single-node growth
	if bintable[2] == 0 then
		minetest.chat_send_all("please note, this code will not grow alone")
	end
	
	rules.survive = {}
	local i = 0
	-- convert the even numbered bits into the survival rules
	for b=2,bits,2 do
		if bintable[b] == 1 then table.insert(rules.survive, i) end
		i = i+1
	end
	rules.birth = {}
	local i = 1
	-- convert the odd numbered bits into the birth rules, skipping the first one (not implemented in this mod)
	for b=3,bits,2 do
		if bintable[b] == 1 then table.insert(rules.birth, i) end
		i = i+1
	end
	--pass the binary table to the rules table to transition to this form of checking in rule_check
	rules.binary = bintable
	return rules
end

-- need a queue so that grown nodes don't get immediately also assessed for growth,
-- automata need to be assessed a layer at a time, not according to whatever scan order is used by MT
automata.block_queue = {}
--need to prevent rescanning of same blocks
automata.check_list = {}

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
		if automata.block_queue[pos] == nil then
			if nodename ~= "air" then automata.block_queue[pos] = {nodename = nodename, gen = gen}
			else automata.block_queue[pos] = {nodename = nodename, gen = nil}
			end
			if CHAT_DEBUG then minetest.chat_send_all(nodename.." node enqueued at "..pos) end
		end
	end
end

-- function to execute the queued commands
function automata:dequeue()
	--if #automata.block_queue > 0 then
		--loop through each entry, keyed by pos with value opts.nodename, opts.gen
		for k,v in pairs(automata.block_queue) do
			local pos = minetest.string_to_pos(k)
			minetest.set_node(pos, {name = v.nodename})
			set_gen(pos,v.gen)
			if CHAT_DEBUG then minetest.chat_send_all("set a gen "..v.gen.." "..v.nodename.." at ("..k..")") end
			-- remove the just executed row
			automata.block_queue[k] = nil
			-- remove the check_list entry as well so the space can be alive again for other gens/nodes
			automata.check_list[k] = nil -- also necessary for VERT = 0 mode
		end
	--end
end

-- then we will use globalstep to execute the queue
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 5 then
		-- process the queue
		automata:dequeue()
		--reset the check_list need to find a better place to flush this... some kind of gen check
		--automata.check_list = {}
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
	automata.check_list[minetest.pos_to_string(pos)] = true
	--minetest.log("action", "checked " .. minetest.pos_to_string(pos))
	return c
end

--the main growth function for all rulesets
local function grow(pos, node, rules)
	
	--first off, have we inspected this active cell yet? if so bail on grow()
	if automata.check_list[minetest.pos_to_string(pos)] ~= nil then 
		return false 
	end
	
	--load the generation metadata
	local gen = get_gen(pos)
	
	--check to see if we automatically perpetuate self
	if #rules.survive > 0 then 
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
	end
	
	--if BIRTH is enabled, we use this opportunity to check all non-active nieghbors
	--by the nature of this scan, we know there is at least one neighbor, so birth=true implies > 0
	if #rules.birth > 0 then
		--load the candidate cells for birthing
		local inactive_neighbors = list_inactive_neighbors(pos, node.name, rules.corners)
		--if specific neighbor counts are listed in the rules we have to count neighbors and then apply a rule check
		for k,v in pairs(inactive_neighbors) do
			--minetest.chat_send_all(k.." : " ..minetest.pos_to_string(v))
			if automata.check_list[minetest.pos_to_string(v)] == nil then
				local cn = count_same_neighbors(v, node.name, rules.corners) --will mark the node as checked
				if rule_check(cn, rules.birth) then
					enqueue({x=v.x,y=v.y+VERT,z=v.z}, node.name, gen+1)
				end
			end
		end
	end	
end
--[[ THESE NODES ARE NO LONGER REGISTERED BY DEFAULT, PROGRAMMABLE NODES NOW USED
-- automata rule 1022 node
minetest.register_node("automata:5n1022", {
	description = "5 Neighbor Code 1022",
	tiles = {"nks1022.png"},
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1},
})

-- automata rule 942 node
minetest.register_node("automata:5n942", {
	description = "5 Neighbor Code 942",
	tiles = {"nks942.png"},
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1},
})
-- same as 942 with no survival
minetest.register_node("automata:5n260", {
	description = "5 Neighbor Code 260",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1},
})
--]]
-- automata rule Conway node
minetest.register_node("automata:9n224", {
	description = "Conway's Game of Life",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {	live_automata = 1, --abm applied to this group only
				oddly_breakable_by_hand=1,
				not_in_creative_inventory = 1 --only programmable nodes appear in the inventory
	},
})
minetest.register_alias("automata:conway", "automata:9n224")

-- automata generic growth action
minetest.register_abm({
	nodenames = {"group:live_automata"},
	neighbors = {"air"}, --won't grow underground or underwater . . .
	interval = 4,
	chance = 1,
	action = function(pos, node)
		local rules = nks_rule_convert(node.name)
		if rules ~= false then
			grow(pos, node, rules)
		else
			minetest.log("error", "rule extrapolation from node name failed")
		end
	end,
})
-- new block that requires punching to activate and
minetest.register_node("automata:programmable", {
	description = "Programmable Automata",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
	
	on_construct = function(pos)
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "field[text;;${text}]")
		meta:set_string("infotext", "\"\"")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		--print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
		if minetest.is_protected(pos, sender:get_player_name()) then
			minetest.record_protection_violation(pos, sender:get_player_name())
			return
		end
		local meta = minetest.get_meta(pos)
		if not fields.text then return end
		minetest.log("action", (sender:get_player_name() or "").." wrote \""..fields.text..
				"\" to sign at "..minetest.pos_to_string(pos))
		meta:set_string("text", fields.text)
		meta:set_string("infotext", '"'..fields.text..'"')
		
		local nodename = "automata:"..fields.text
		--see if the entered data is a valid NKS rule
		local validates = nks_rule_convert(nodename)
		if validates == false then return false end
		
		--check to see if this node is already a registered node
		if not minetest.registered_nodes[nodename] then
			--if not register the node ON THE FLY!
			minetest.register_node(nodename, {
				description = "Automata code "..fields.text,
				tiles = {"conway.png"},
				light_source = 5,
				groups = {	live_automata = 1, --abm applied to this group only
							oddly_breakable_by_hand=1,
							not_in_creative_inventory = 1 --only programmable nodes appear in the inventory
				},
			})
			--and add it to the automata node file
			if not automata:save_node(nodename) then
				minetest.chat_send_all("saving the "..nodename..fields.text.." to persistence file failed")
			end
			minetest.chat_send_all(nodename.." has been registered as a new automata type in this world")
		else
			minetest.chat_send_all(nodename.." is already a registered automata type in this world")
		end
		
		--convert this block to the entered type
		minetest.set_node(pos, {name=nodename})
		
	end,
})

-- upon server start, read the savefile
automata.restore_data();
