automata = {}
--[[
PROPERTY: automata.patterns
TYPE: table
DESC: patterns are a table of the current state of any automata patterns in the world
FORMAT: automata.patterns[i] = {
			iteration=0, -- the current generation of the pattern
			last_cycle=0, -- last check cycle applied
			rule_id=0, -- reference to the rule registry row
			pmin=0, -- pmin and pmax give the bounding volume for pattern
			pmax=0,
			cell_count=0, -- how many active cells in pattern, 
			cell_list={} -- indexed by position hash value = true		
PERSISTENCE: this table is persisted to a file, minus the cell table
             this table is loaded from a file on mod load time, but the cell lists
             must be repopulated at first grow() (or each time if VM used...)
TODO: might want player ownership
--]]
automata.patterns = {}

--[[
PROPERTY: automata.inactive_cells
TYPE: table
DESC: a table of inactive cells to be activated by next use of the RemoteControl
FORMAT: indexed by position hash value = true
PERSISTENCE: this file is persisted to a file on change and loaded at mod start
TODO: might move this to the automata.patterns with a reserved id that grow() skips
--]]
automata.inactive_cells = {}

--[[
PROPERTY: automata.rule_registry
TYPE: table
DESC: any rule combination that passes validation is saved in this rule_registry
FORMAT: automata.rule_registry[i] = rules --may add player name, etc
PERSISTENCE: this table is persisted to a file, loaded at mod startup
--]]
automata.rule_registry = {}

--[[
PROPERTY: automata.current_cycle
TYPE: integer
DESC: keeps track of the current grow cycle, which is not the same as iteration
PERSISTENCE: at mod load, the highest automata.patterns last_cycle is used to set
--]]
automata.current_cycle = 0

--[[
METHOD: automata.load_from_files()
RETURN: nothing yet
DESC: loads the PERSISTENCE files to restore automata patterns run at end of init.lua
--]]
function automata.load_from_files()

end

--[[
METHOD: automata.save_to_files()
RETURN: nothing yet
DESC: saves the PERSISTENCE files for pattern survival onshutdown/crash
--]]
function automata.save_to_files()

end


--[[
METHOD: automata.grow(pattern_id)
RETURN: nothing yet
DESC: looks at each pattern, applies the rules to generate a death list, birth list then
      then sets the nodes and updates the pattern table settings and cell_list
TODO: use voxelmanip for this
--]]
function automata.grow(pattern_id)
	local death_list ={} --cells that will be set to rules.trail at the end of grow()
	local life_list = {} --cells that will be set to automata:active at the end of grow()
	local empty_neighbors = {} --non -active neighbor cell list to be tested for births
	local new_cell_list = {} --the final cell list to transfer back to automata.patterns[pattern_id]
							 -- some of ^ will be cells that survived in a growth=0 ruleset
							 -- ^ this is to save the time of setting nodes and meta for survivals
	local new_pmin = {x=0,y=0,z=0}
	local new_pmax = {x=0,y=0,z=0}
	--load the rules
	local rules = automata.rule_registry[automata.patterns[pattern_id].rule_id]
	--minetest.log("error", "line 84 = rules: "..dump(rules))
	if automata.patterns[pattern_id].iteration == rules.ttl then
		local is_final = true
	else
		local is_final = false
	end
	--minetest.log("error", "iteration: "..automata.patterns[pattern_id].iteration)
	local neighborhood= {}
	local growth_offset = {}
	-- determine neighborhood and growth offsets
	if rules.neighbors == 4 or rules.neighbors == 8 then -- von Neumann neighborhood
		if rules.plane == "x" then --actually the plane yz
			growth_offset = {x = rules.growth, y=0, z=0}
			neighborhood.n  = {x=  0,y=  1,z=  0}
			neighborhood.e  = {x=  0,y=  0,z=  1}
			neighborhood.s  = {x=  0,y= -1,z=  0}
			neighborhood.w  = {x=  0,y=  0,z= -1}
		elseif rules.plane == "y" then --actually the plane xz
			growth_offset = {x=0, y = rules.growth, z=0}
			neighborhood.n  = {x=  0,y=  0,z=  1}
			neighborhood.e  = {x=  1,y=  0,z=  0}
			neighborhood.s  = {x=  0,y=  0,z= -1}
			neighborhood.w  = {x= -1,y=  0,z=  0}
		elseif rules.plane == "z" then --actually the plane xy
			growth_offset = {x=0, y=0, z = rules.growth}
			neighborhood.n  = {x=  0,y=  1,z=  0}
			neighborhood.e  = {x= -1,y=  0,z=  0}
			neighborhood.s  = {x=  0,y= -1,z=  0}
			neighborhood.w  = {x=  1,y=  0,z=  0}
		else
			--something went wrong
		end
	end
	if rules.neighbors == 8 then -- add missing Moore neighborhood corners
		if rules.plane == "x" then
			neighborhood.ne = {x=  0,y=  1,z=  1}
			neighborhood.se = {x=  0,y= -1,z=  1}
			neighborhood.sw = {x=  0,y= -1,z= -1}
			neighborhood.nw = {x=  0,y=  1,z= -1}
		elseif rules.plane == "y" then
			neighborhood.ne = {x=  1,y=  0,z=  1}
			neighborhood.se = {x=  1,y=  0,z= -1}
			neighborhood.sw = {x= -1,y=  0,z= -1}
			neighborhood.nw = {x= -1,y=  0,z=  1}
		elseif rules.plane == "z" then
			neighborhood.ne = {x= -1,y=  1,z=  0}
			neighborhood.se = {x= -1,y= -1,z=  0}
			neighborhood.sw = {x=  1,y= -1,z=  0}
			neighborhood.nw = {x=  1,y=  1,z=  0}
		else
			--minetest.log("error", "neighbors: "..neighbors.." is invalid")
		end
	end
	
	--loop through cell list
	for pos_hash,v in next, automata.patterns[pattern_id].cell_list do
		local same_count = 0
		local pos = minetest.get_position_from_hash(pos_hash) --@todo, figure out how to add / subtract hashes
		for k, offset in next, neighborhood do
			--add the offsets to the position @todo although this isn't bad
			local npos = {x=pos.x+offset.x, y=pos.y+offset.y, z=pos.z+offset.z}
			--could check if it is even an automata:active but we will skip even loading the node
			local meta = minetest.get_meta(npos)
			if meta:get_int("pattern_id") == pattern_id then
				same_count = same_count +1
			else
				table.insert(empty_neighbors, npos)
			end
		end
		--now we have a same neighbor count, apply life and death rules
		local gpos = {}
		--minetest.log("error", "line 154 = rules.survive: ".. rules.survive..", same_count: "..same_count)
		if string.find(rules.survive, same_count) then
			--add to life list
			gpos = {x=pos.x+growth_offset.x, y=pos.y+growth_offset.y, z=pos.z+growth_offset.z}

			if rules.growth ~= 0 then
				table.insert(life_list, gpos) --when node is actually set we will add to new_cell_list
				table.insert(death_list, pos) --with growth, the old pos dies leaving rules.trail
			else
				--in the case that this is the final iteration, we need to pass it to the life list afterall
				if is_final then
					table.insert(life_list, pos) --when node is actually set we will add to new_cell_list
				else
					new_cell_list[pos_hash] = true --if growth=0 we just let it be but add to new_cell_list
					--oh, we also have to test it against the pmin and pmax
					for k,v in next, pos do
						if pos[k] < new_pmin[k] then new_pmin[k] = pos[k] end
						if pos[k] > new_pmax[k] then new_pmax[k] = pos[k] end
					end
				end
			end
			
		else
			--add to death list, regardless of growth setting
			table.insert(death_list, pos)
		end
	end
	--loop through the new total neighbors list
	for i,epos in next, empty_neighbors do
		local same_count = 0
		for k, offset in next, neighborhood do
			--add the offsets to the position @todo although this isn't bad
			local npos = {x=epos.x+offset.x, y=epos.y+offset.y, z=epos.z+offset.z}
			--could check if it is even an automata:active but we will skip even loading the node
			local meta = minetest.get_meta(npos)
			if meta and meta:get_int("pattern_id") == pattern_id then
				same_count = same_count +1
			end
		end
		local bpos = {}
		if string.find(rules.birth, same_count) then
			--add to life list
			bpos = {x=epos.x+growth_offset.x, y=epos.y+growth_offset.y, z=epos.z+growth_offset.z}
			table.insert(life_list, bpos) --when node is actually set we will add to new_cell_list
		end
	end
	
	--set the nodes for deaths
	for k,dpos in next, death_list do
		minetest.set_node(dpos, {name=rules.trail})
	end
	--set the nodes for births
	--minetest.log("action", "life_list: "..dump(life_list))
	for k,bpos in next, life_list do --@todo why is this processing an empty table life_list!?
		--test for final iteration
		if is_final then
			minetest.set_node(bpos, {name=rules.final})
		else
			minetest.set_node(bpos, {name="automata:active"})
			local meta = minetest.get_meta(bpos)
			meta:set_int("pattern_id", pattern_id)
			--add to cell_list
			--minetest.log("action", "bpos: "..dump(bpos))
			new_cell_list[minetest.hash_node_position(bpos)] = true
			for k,v in next, bpos do
				if bpos[k] < new_pmin[k] then new_pmin[k] = bpos[k] end
				if bpos[k] > new_pmax[k] then new_pmax[k] = bpos[k] end
			end
		end
	end
	
	if is_final then
		--remove the pattern from the registry
		automata.patterns[pattern_id] = nil
	else
		--update the pattern values: iteration, last_cycle, cell_count, cell_list
		automata.patterns[pattern_id].iteration = automata.patterns[pattern_id].iteration +1
		automata.patterns[pattern_id].last_cycle = automata.current_cycle
		automata.patterns[pattern_id].pmin = new_pmin
		automata.patterns[pattern_id].pmax = new_pmax
		automata.patterns[pattern_id].cell_count = table.getn(new_cell_list)
		automata.patterns[pattern_id].cell_list = new_cell_list
	end
end



--[[
METHOD: automata.validate(fields)
RETURN: rule_id (a reference to the automata.rule_registry)
DESC: if the rule values are valid, make an entry into the rules table and return the id
      defaults are set to be Conway's Game of Life
TODO: heavy development of the formspec expected
--]]
function automata.rules_validate(fields) --
	local rules = {}
	--minetest.chat_send_all("here :"..dump(fields))
	
	fields.code = fields.code and "2/23" or fields.code
	local split = string.find(fields.code, "/")
	if split then
		-- take the values to the left and the values to the right @todo validation will be made moot by a stricter form
		rules["birth"] = string.sub(fields.code, 1, split-1)
		rules["survive"] = string.sub(fields.code, split+1)
		
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
	
	--add the rule to the rule_registry @todo, need to check to see if this rule is already in the list (checksum?)
	table.insert(automata.rule_registry, rules)
	local rule_id = #automata.rule_registry
	return rule_id
end

--[[ MINETEST CALLBACKS:--]]

-- REGISTER GLOBALSTEP
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 5 then
		--increment the current cycle
		automata.current_cycle = automata.current_cycle +1
		--process each pattern
		for pattern_id, v in next, automata.patterns do
			--@todo check if this pattern is even partially loaded, if not skip
			automata.grow(pattern_id)
		end
	timer = 0
	end
end)

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
      AND IT'S ACTIVATION AS A PATTERN --]]

-- new block that requires activation
minetest.register_node("automata:inactive", {
	description = "Programmable Automata",
	tiles = {"inactive.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
	
	on_construct = function(pos)
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "\"Inactive Automata\"")
		--register the cell in the cell registry
		automata.inactive_cells[minetest.hash_node_position(pos)] = true
	end,
	on_dig = function(pos)
		--remove from the inactive cell registry (should be called by set_node)
		automata.inactive_cells[minetest.hash_node_position(pos)] = nil
	end,
})

-- an activated automata block -- further handling of this node done by globalstep
minetest.register_node("automata:active", {
	description = "Active Automata",
	tiles = {"active.png"},
	drop = { max_items = 1, items = { "automata.inactive" } }, -- change back to inactive when dug 
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1},
	on_dig = function(pos)
		--get the pattern ID from the meta and remove the cell from the pattern table
		local meta=minetest.get_meta(pos)
		local pattern_id = meta:get_int("pattern_id")
		automata.patterns[pattern_id].cell_list[minetest.hash_node_position(pos)] = nil
		--@todo also check for pmin/pmax change
		automata.patterns[pattern_id].cell_count = automata.patterns[pattern_id].cell_count -1
	end,
})

-- the controller for activating cells
minetest.register_tool("automata:remote" , {
	description = "Automata Trigger",
	inventory_image = "remote.png",
	on_use = function (itemstack, user, pointed_thing)
		local pname = user:get_player_name()
		
		--make sure the inactive cell registry is not empty
		if next(automata.inactive_cells) then
		minetest.show_formspec(pname, "automata:rc_form",
			"size[8,9]" ..
			"field[1,1;2,1;neighbors;Neighbors (4 or 8);]" ..
			"field[3,1;4,1;code;Rules (eg: 2/23);]" ..
			
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
		local rule_id = automata.rules_validate(fields) --will be false if rules don't validate
		if rule_id then
			--create the new pattern id empty
			table.insert(automata.patterns, true) --placeholder to get id
			local pattern_id = #automata.patterns
			local pos = {}
			local cell_list = {}
			local pmin, pmax = {}
			--activate all inactive nodes @todo handle this with voxelmanip
			for pos_hash,_ in pairs(automata.inactive_cells) do --@todo check ownership of node? lock registry?
				pos = minetest.get_position_from_hash(pos_hash)
				minetest.set_node(pos, {name="automata:active"})
				cell_list[pos_hash] = true
				--wipe the inactive cell registry
				automata.inactive_cells[pos_hash] = nil -- might not need this with after_destruct()
				--add the pattern id to the metadata of each node we just converted
				local meta = minetest.get_meta(pos)
				meta:set_int("pattern_id", pattern_id)
				--test against pmin and pmax (and first value has to be the first value)
				--minetest.log("action", "pmin: "..dump(pmin)..", pmax: "..dump(pmax)..", pos: "..dump(pos))
				--minetest.log("action", "pmin size: "..table.getn(pmin))
				if table.getn(pmin) > 0 then
					for k,v in next, pos do
						if pos[k] < pmin[k] then pmin[k] = pos[k] end
						if pos[k] > pmax[k] then pmax[k] = pos[k] end
					end
				else
					pmin, pmax = pos
				end
			end
			
			--add the cell list to the active cell registry with the ttl, rules hash, and cell list
			local values = {iteration=0, last_cycle=0, rule_id=rule_id, pmin=pmin, pmax=pmax, cell_count=table.getn(cell_list), cell_list=cell_list}
			automata.patterns[pattern_id] = values --overwrite placeholder	
			
			minetest.chat_send_player(player:get_player_name(), "You activated all inactive cells!")
			return true
		else
			minetest.chat_send_player(player:get_player_name(), "Something was wrong with your inputs!")
		end
	end
	
end)

--at mod load restore persistence files
automata.load_from_files()