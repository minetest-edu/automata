automata = {}

--[[ FOR THE QUEUEING, PROCESSING AND
     ELIMINATION OF CHECKING REDUNDANCY --]]
	 
--the Advanced Block Modifier checking interval system is not good enough for our purposes
--because the newly created nodes seem to get included in the original search and so the growth
--of cellular automata is determined by the search order of minetest's ABM system, rather than
--by our generations. @todo, make this even more structured, using ttl and fingerprint to make sure
--that all of the previous generation are processed before we process the next generation
--@todo there is also the issue of ABMs not being processed if out of range of the player.

--the queue is there to prevent the creation of more than one block in one spot
--in fact it is used to save time even checking a block that is enqueued to become something
automata.block_queue = {} --indexed by pos_to_string(pos) and value = meta:to_table() or nodename

--the checklist is there to make sure that nodes are not scanned twice by grow() (this will stop other automata from scanning)
automata.check_list = {} -- indexed by pos_to_string(pos) and value = true (@todo, make this fingerprint..ttl specific)

--each round of checking needs an id
automata.check_count = 0

--moving away from ABMs we need our own node list
automata.inactive_cell_registry = {} -- indexed by pos_string
automata.active_cell_registry={} -- indexed by fingerprint, value is {ttl, rules_hash, cell_list} , cell_list is indexed by pos_string
automata.rulesets={} -- indexed by rules_hash which is just serialized rules table

-- function to add nodes to the iteration queue
local function enqueue(pos, data)
	--pos is passed as a table but we need it as a string for indexing
	local pos = minetest.pos_to_string(pos)
	--checks to see if the block is already enqueued to change, (first come first served)
	if automata.block_queue[pos] == nil then
		--minetest.log("action", "enqueued at pos: "..pos)
		automata.block_queue[pos] = data
	end
end

-- function to execute the queued commands
function automata:process_queue()
	--loop through each entry, keyed by pos with value opts.nodename, opts.gen
	for k,v in pairs(automata.block_queue) do
		local pos = minetest.string_to_pos(k)
		--determine if this is a life or death based on the type of v
		if type(v) == "table" then --table means life
			--test the ttl to determine if this is the final node
			if tonumber(v.fields.ttl) <= 1 then
				--skip creating an active cell with ttl=0 and just make the final node
				if v.fields.final then
					minetest.set_node(pos,{name=v.fields.final})
				else
					minetest.set_node(pos,{name=v.fields.trail})
				end
			else
				minetest.set_node(pos,{name=v.fields.nodename}) --allows for explicitly registered types like conway
				local meta = minetest.get_meta(pos)
				meta:from_table(v) --load the serialized table into the new node's meta object
				meta:set_int("ttl",v.fields.ttl-1) --count down the ttl
			end
		--string means death
		elseif type(v) == "string" then
			minetest.set_node(pos,{name=v})
		end
		
		-- remove the just executed row in the queue
		automata.block_queue[k] = nil
		
		-- remove the check_list entry as well so the space can be alive again for other gens/nodes
		automata.check_list[k] = nil -- also necessary for VERT = 0 mode
	end
end

-- then we will use globalstep to execute the queue
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 5 then
		-- 1. process the queue
		automata:process_queue()
		timer = 0
		--minetest.log("action", "block_queue: "..dump(automata.block_queue))
		--minetest.log("action", "check_list: "..dump(automata.check_list))
		
		--erase all check_list items from this round of checking and increment
		for k,v in pairs(automata.check_list) do -- just resetting this table each globalstep seems to work too
			if v == automata.check_count then automata.check_list[k]= nil end -- wipe all entries from last check round
		end
		automata.check_count = automata.check_count + 1 
		-- 2. grow all active cells
		--loop through each pattern in the active cell registry and do grow() on each node
		for fingerprint,values in pairs(automata.active_cell_registry) do
			--one pattern at a time

			for pos_string,_ in pairs(values.cell_list) do --cell_list is indexed by pos_string
				grow(pos_string, fingerprint, values.ttl, minetest.unserialize(values.rules_hash)) --these needed for enqueue
			end
		end
	end
end)

--[[ FOR THE GROWTH OF ACTIVE AUTOMATA BLOCKS --]]

--based on the number of neighbors (5 or 9), the plane, position, and the fingerprint of an automata
--will return the count of same neighbors, and a list of non-same neighbors
local function list_neighbors(pos, neighbors, plane, fingerprint, ttl)
	--minetest.log("action", "neighbors: "..neighbors..", plane: "..plane..", print: "..fingerprint..", ttl: "..ttl)
	local list = {}
	if neighbors == 4 or neighbors == 9 then -- von Neumann neighborhood
		if plane == "x" then --actually the plane yz
			list.n  = {x=pos.x,  y=pos.y+1,  z=pos.z}
			list.e  = {x=pos.x,  y=pos.y,    z=pos.z+1}
			list.s  = {x=pos.x,  y=pos.y-1,  z=pos.z}
			list.w  = {x=pos.x,  y=pos.y,    z=pos.z-1}
		elseif plane == "y" then --actually the plane xz
			list.n  = {x=pos.x,  y=pos.y,z=pos.z+1}
			list.e  = {x=pos.x+1,y=pos.y,z=pos.z}
			list.s  = {x=pos.x,  y=pos.y,z=pos.z-1}
			list.w  = {x=pos.x-1,y=pos.y,z=pos.z}
		elseif plane == "z" then --actually the plane xy
			list.n  = {x=pos.x,  y=pos.y+1,z=pos.z}
			list.e  = {x=pos.x-1,y=pos.y,z=pos.z}
			list.s  = {x=pos.x,  y=pos.y-1,z=pos.z}
			list.w  = {x=pos.x+1,y=pos.y,z=pos.z}
		else
			--something went wrong
		end
	end
	if neighbors == 8 then -- Moore neighborhood
		if plane == "x" then
			list.ne = {x=pos.x,y=pos.y+1,z=pos.z+1}
			list.se = {x=pos.x,y=pos.y-1,z=pos.z+1}
			list.sw = {x=pos.x,y=pos.y-1,z=pos.z-1}
			list.nw = {x=pos.x,y=pos.y+1,z=pos.z-1}
		elseif plane == "y" then
			list.ne = {x=pos.x+1,y=pos.y,z=pos.z+1}
			list.se = {x=pos.x+1,y=pos.y,z=pos.z-1}
			list.sw = {x=pos.x-1,y=pos.y,z=pos.z-1}
			list.nw = {x=pos.x-1,y=pos.y,z=pos.z+1}
		elseif plane == "z" then
			list.ne = {x=pos.x-1,y=pos.y+1,z=pos.z}
			list.se = {x=pos.x-1,y=pos.y-1,z=pos.z}
			list.sw = {x=pos.x+1,y=pos.y-1,z=pos.z}
			list.nw = {x=pos.x+1,y=pos.y+1,z=pos.z}
		else
			--minetest.log("error", "neighbors: "..neighbors.." is invalid")
		end
	end
	
	local same_count = 0
	local inactive_neighbors = {} --will include any node other than the identical fingerprint and generation
	
	for _,v in pairs(list) do
		local meta = minetest.get_meta(v)
		--minetest.log("action", fingerprint..":"..meta:get_int("fingerprint")..", "..ttl..":".. meta:get_int("ttl"))
		--minetest.log("action", minetest.pos_to_string(v))
		if fingerprint == meta:get_int("fingerprint") and ttl == meta:get_int("ttl") then
			same_count = same_count + 1
		else
			table.insert(inactive_neighbors, v)
		end
	end
	-- mark the node as checked
	automata.check_list[minetest.pos_to_string(pos)] = automata.check_count --causing problems?
	--minetest.log("action", "count active: "..same_count..", count inactive: "..#inactive_neighbors)
	return same_count, inactive_neighbors
end

--new metadata based grow function
local function grow(pos_string, fingerprint, rules)
	
	--first we see if this node has never been checked
	if automata.check_list[pos_string] ~= automata.check_count then 
		--minetest.log("action", "not already checked")
				
		--now we must count the neighbors, identify how many are the same and which ones are not
		local same_count, inactive_neighbors = list_neighbors(minetest.string_to_pos(pos_string), fingerprint) --marks this node as checked
		
		--survival rules for this node applied
		--minetest.log("action", "before survival rules: "..binrules)
		--minetest.log("action", "newpos before survival rules: "..minetest.pos_to_string(pos))
		if string.find(rules.survive, same_count) then
			
			local newpos = {}
			if     rules.plane == "x" then newpos = {x=pos.x+rules.growth, y=pos.y, z=pos.z}
			elseif rules.plane == "y" then newpos = {x=pos.x, y=pos.y+rules.growth, z=pos.z}
			elseif rules.plane == "z" then newpos = {x=pos.x, y=pos.y, z=pos.z+rules.growth}
			end
			--minetest.log("action", "newpos after survival rules: "..minetest.pos_to_string(newpos))
			
			--if growth is set for this node, then we not only enqueue the next gen, but we set the old block to die
			if growth ~= 0 then enqueue_death(pos, fingerprint) end --passing a string implies death
			--regardless of growth setting we enqueue the next generation for life
			enqueue_life(newpos, fingerprint) --passing a table implies life
		else
			--if survival fails we enqueue current cell for death
			enqueue_death(pos, fingerprint) --passing a string implies death
		end
		
		--birth rules for all inactive neighbors checked
		if inactive_neighbors then
			for _,v in pairs(inactive_neighbors) do
				if automata.check_list[minetest.pos_to_string(v)] ~= automata.check_count --already checked
				and automata.block_queue[minetest.pos_to_string(v)] == nil then --already has a destiny
					local sc, _ = list_neighbors(v, fingerprint) --will mark the node as checked
					--based on the birth rules turn this new cell on
					if string.find(rules.birth, sc) then
						local newpos = {}
						if     rules.plane == "x" then newpos = {x=v.x+rules.growth, y=v.y, z=v.z}
						elseif rules.plane == "y" then newpos = {x=v.x, y=v.y+rules.growth, z=v.z}
						elseif rules.plane == "z" then newpos = {x=v.x, y=v.y, z=v.z+rules.growth}
						end
						enqueue_life(newpos, fingerprint) --passing a table implies life
					end
				end
			end
		end
	end
	return true --end of the grow function
end

-- force load a block (taken from technic)
-- if the node is loaded, returns it. If it isn't loaded, load it and return nil.
function get_or_load_node(pos)
	local node_or_nil = minetest.get_node_or_nil(pos)
	if node_or_nil then return node_or_nil end
	local vm = VoxelManip()
	local MinEdge, MaxEdge = vm:read_from_map(pos, pos)
	return nil
end

-- a generic node type for the new metadata-based growth function
minetest.register_node("automata:active", {
	description = "Active Automaton",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {	live_automata = 1, --abm applied to this group only
				oddly_breakable_by_hand=1,
				not_in_creative_inventory = 1 --only programmable nodes appear in the inventory
	},
})


--[[  FOR THE CREATION OF A PROGRAMMABLE BLOCK,
      AND IT'S ACTIVATION AS A LIVE AUTOMATA BLOCK --]]

-- new block that requires activation
minetest.register_node("automata:inactive", {
	description = "Programmable Automata",
	tiles = {"dead.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
	
	on_construct = function(pos)
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "\"Inactive Automata\"")
		--register the cell in the cell registry
		automata.inactive_cell_registry[minetest.pos_to_string(pos)] = true -- the cell_registry will change this to the rule hash when active
	end,
	
})

-- the controller for activating cells
minetest.register_tool("automata:remote" , {
	description = "Automata RC",
	inventory_image = "nks942.png",
	on_use = function (itemstack, user, pointed_thing)
		local pname = user:get_player_name()
		
		--make sure the inactive cell registry is not empty
		if next(automata.inactive_cell_registry) then
		minetest.show_formspec(pname, "automata:rc_form",
			"size[8,9]" ..
			"field[1,1;4,1;neighbors;Neighbors (4 or 8);]" ..
			"field[1,5;4,1;code;Rules (eg: 2/23);]" ..
			
			"field[1,2;4,1;plane;Plane (x, y, or z);]" ..
			"field[1,3;4,1;growth;Growth (-1, 0, 1, 2 ...);]" ..
			"field[1,4;4,1;trail;Trail Block (eg: default:dirt);]" ..
			"field[1,5;4,1;final;Final Block (eg: default:mese);]" ..
			"field[1,6;4,1;ttl;Generations (eg: 30);]" ..
			"button_exit[1,7;2,1;exit;Activate]")
		else
			minetest.chat_send_player(pname, "There are no inactive cells placed to activate!")
		end
	end,
})

-- Processing the form from the RC
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "automata:rc_form" then
		-- form validation
		local rules_hash = rules_validate(fields) --will be false if rules don't validate
		if rules_hash then
			local cell_list = {}
			--activate all inactive nodes @todo handle this with voxelmanip
			for pos_string,_ in pairs(automata.inactive_cell_registry) do --@todo check ownership of node? lock registry?
				minetest.set_node(minetest.string_to_pos(pos_string), {name="automata:active"})
				table.insert(cell_list, pos_string)
				--wipe the inactive cell registry
				automata.inactive_cell_registry[pos_string] = nil
			end
			--create a unique fingerprint for this activated set
			local fingerprint = math.random(1,100000)
			--in case we won the lottery and this fingerprint is already in use...
			while automata.active_cell_registry[fingerprint] do
				local fingerprint = math.random(1,100000)
			end
			--add the cell list to the active cell registry with the ttl, rules hash, and cell list
			automata.active_cell_registry[fingerprint] = {ttl=fields.ttl, rules_hash=rules_hash, cell_list=cell_list}
			
			minetest.chat_send_player(player:get_player_name(), "You activated all inactive cells!")
			return true
		else
			minetest.chat_send_player(player:get_player_name(), "Something was wrong with your inputs!")
		end
	end
	
end)

function rules_validate(fields) --
	local rules = {}
	--local pname = user:get_player_name()
	--minetest.chat_send_all("here :"..dump(fields))
	
	fields.code = fields.code and "2/23" or fields.code
	local split = string.find(fields.code, "/")
	if split then
		-- take the values to the left and the values to the right @todo validation will be made moot by a stricter form
		rules["birthrules"] = string.sub(fields.code, 1, split-1)
		rules["suriviverules"] = string.sub(fields.code, split+1)
		
	else
		--minetest.chat_send_player(pname, "the rule code should be in the format \"2/23\"")
		return false
	end
	
	rules["neighbors"] = fields.neighbors and 8 or fields.neighbors
	rules["ttl"] = fields.ttl and 30 or fields.ttl
	rules["growth"] = fields.growth and 0 or fields.growth
	rules["plane"] = fields.plane and "y" or fields.growth
	rules["trail"] = fields.trail and "air" or fields.trail
	rules["final"] = fields.final and "stone" or fields.final
	
	return rules
end



-- an activated automata block -- further handling of this node done by globalstep
minetest.register_node("automata:active", {
	description = "Active Automata",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1},
})

