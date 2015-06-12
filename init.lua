automata = {}
--[[
PROPERTY: automata.patterns
TYPE: table
DESC: patterns are a table of the current state of any automata patterns in the world
FORMAT: automata.patterns[i] = {
			creator = playername
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
--]]
automata.patterns = {}

--[[
PROPERTY: automata.inactive_cells
TYPE: table
DESC: a table of inactive cells to be activated by next use of the RemoteControl
FORMAT: indexed by position hash value = true
PERSISTENCE: this file is persisted to a file on change and loaded at mod start
@TODO: might move this to the automata.patterns with a reserved id that grow() skips
--]]
automata.inactive_cells = {}

--[[
PROPERTY: automata.rule_registry
TYPE: table
DESC: any rule combination that passes validation is saved in this rule_registry
FORMAT: automata.rule_registry[i] = rules
PERSISTENCE: this table is persisted to a file, loaded at mod startup
--]]
automata.rule_registry = {}

--[[
PROPERTY: automata.current_cycle
TYPE: integer
DESC: keeps track of the current grow cycle, which is not the same as iteration
PERSISTENCE: at mod load, the highest automata.patterns last_cycle is used to set
@TODO: this might not even be necessary
--]]
automata.current_cycle = 0

--[[ PERSISTENCE: not yet working
METHOD: automata.save_patterns_to_file()
RETURN: nothing yet
DESC: saves the PERSISTENCE files for pattern survival onshutdown/crash
--]
function automata.save_patterns_to_file()
	local file = io.open(minetest.get_worldpath().."/patterns", "w")
	if file then
		for k,v in next, automata.patterns do
			line = {key=k, values=v}
			file:write(minetest.serialize(line).."\n")
		end
		file:close()
		minetest.log("action", "savings automata patterns to file")
	end
end

--[
METHOD: automata.save_rules_to_file()
RETURN: nothing yet
DESC: saves the PERSISTENCE files for pattern survival onshutdown/crash
--]
function automata.save_rules_to_file()
	local file = io.open(minetest.get_worldpath().."/rule_registry", "w")
	if file then
		for k,v in next, automata.rule_registry do
			line = {key=k, values=v}
			file:write(minetest.serialize(line).."\n")
		end
		file:close()
		minetest.log("action", "savings automata rules to file")
	end
end
--]]

--[[
METHOD: automata.grow(pattern_id)
RETURN: nothing yet
DESC: looks at each pattern, applies the rules to generate a death list, birth list then
      then sets the nodes and updates the pattern table settings and cell_list
TODO: use voxelmanip for this
--]]
function automata.grow(pattern_id)
	local t1 = os.clock()
	--update the pattern values: iteration, last_cycle
	automata.patterns[pattern_id].iteration = automata.patterns[pattern_id].iteration +1
	automata.patterns[pattern_id].last_cycle = automata.current_cycle
	local death_list ={} --cells that will be set to rules.trail at the end of grow()
	local life_list = {} --cells that will be set to automata:active at the end of grow()
	local empty_neighbors = {} --non -active neighbor cell list to be tested for births
	local new_cell_list = {} --the final cell list to transfer back to automata.patterns[pattern_id]
							 -- some of ^ will be cells that survived in a grow_distance=0 ruleset
							 -- ^ this is to save the time of setting nodes for survival cells
	local new_pmin = {x=0,y=0,z=0}
	local new_pmax = {x=0,y=0,z=0}
	--load the rules
	local rules = automata.patterns[pattern_id].rules
	local is_final = 0
	if automata.patterns[pattern_id].iteration == rules.gens then
		is_final = 1
	end
	if not rules.grow_distance then rules.grow_distance = 0 end --in the case of 3D!
	
	local neighborhood= {}
	local growth_offset = {x=0,y=0,z=0} --again this default is for 3D @TODO should skip the application of offset lower down
		
	-- determine neighborhood and growth offsets (works for 1D and 2D)
	if rules.neighbors == 2 or rules.neighbors == 4 or rules.neighbors == 8 then
		if rules.grow_axis == "x" then
			growth_offset = {x = rules.grow_distance, y=0, z=0}
		elseif rules.grow_axis == "z" then
			growth_offset = {x=0, y=0, z = rules.grow_distance}
		else --grow_axis is y
			growth_offset = {x=0, y = rules.grow_distance, z=0}
		end
	end
	-- 1D neighbors
	if rules.neighbors ==2 then
		if rules.axis == "x" then
			neighborhood.e = {x=  1,y=  0,z=  0}
			neighborhood.w = {x= -1,y=  0,z=  0}
		elseif rules.axis == "z" then
			neighborhood.n = {x=  0,y=  0,z=  1}
			neighborhood.s = {x=  0,y=  0,z= -1}
		else --rules.axis == "y"
			neighborhood.t = {x=  0,y=  1,z=  0}
			neighborhood.b = {x=  0,y= -1,z=  0}
		end
	else --2D and 3D neighbors
		if rules.neighbors == 4 or rules.neighbors == 8 -- 2D von Neumann neighborhood
		or rules.neighbors == 6 or rules.neighbors == 18 or rules.neighbors == 26 then
			if rules.grow_axis == "x" then --actually the calculation plane yz
				neighborhood.n  = {x=  0,y=  1,z=  0}
				neighborhood.e  = {x=  0,y=  0,z=  1}
				neighborhood.s  = {x=  0,y= -1,z=  0}
				neighborhood.w  = {x=  0,y=  0,z= -1}
			elseif rules.grow_axis == "z" then --actually the calculation plane xy
				neighborhood.n  = {x=  0,y=  1,z=  0}
				neighborhood.e  = {x= -1,y=  0,z=  0}
				neighborhood.s  = {x=  0,y= -1,z=  0}
				neighborhood.w  = {x=  1,y=  0,z=  0}
			else --grow_axis == "y"  --actually the calculation plane xz (or we are in 3D)
				neighborhood.n  = {x=  0,y=  0,z=  1}
				neighborhood.e  = {x=  1,y=  0,z=  0}
				neighborhood.s  = {x=  0,y=  0,z= -1}
				neighborhood.w  = {x= -1,y=  0,z=  0}
			end
		end
		if rules.neighbors == 8 -- add missing 2D Moore corners
		or rules.neighbors == 18 or rules.neighbors == 26 then
			if rules.grow_axis == "x" then
				neighborhood.ne = {x=  0,y=  1,z=  1}
				neighborhood.se = {x=  0,y= -1,z=  1}
				neighborhood.sw = {x=  0,y= -1,z= -1}
				neighborhood.nw = {x=  0,y=  1,z= -1}
			elseif rules.grow_axis == "z" then
				neighborhood.ne = {x= -1,y=  1,z=  0}
				neighborhood.se = {x= -1,y= -1,z=  0}
				neighborhood.sw = {x=  1,y= -1,z=  0}
				neighborhood.nw = {x=  1,y=  1,z=  0}
			else --grow_axis is y or we are in 18n or 26n 3D
				neighborhood.ne = {x=  1,y=  0,z=  1}
				neighborhood.se = {x=  1,y=  0,z= -1}
				neighborhood.sw = {x= -1,y=  0,z= -1}
				neighborhood.nw = {x= -1,y=  0,z=  1}
			end
		end
		if rules.neighbors == 6 or rules.neighbors == 18 or rules.neighbors == 26 then --the 3D top and bottom neighbors
			neighborhood.t = {x=  0,y=  1,z=  0}
			neighborhood.b = {x=  0,y= -1,z=  0}
		end
		if rules.neighbors == 18 or rules.neighbors == 26 then -- the other 3D planar edge neighbors
			neighborhood.tn = {x=  0,y=  1,z=  1}
			neighborhood.te = {x=  1,y=  1,z=  0}
			neighborhood.ts = {x=  0,y=  1,z= -1}
			neighborhood.tw = {x= -1,y=  1,z=  0}		
			neighborhood.bn = {x=  0,y= -1,z=  1}
			neighborhood.be = {x=  1,y= -1,z=  0}
			neighborhood.bs = {x=  0,y= -1,z= -1}
			neighborhood.bw = {x= -1,y= -1,z=  0}
		end
		if rules.neighbors == 26 then -- the extreme 3D Moore corner neighbors
			neighborhood.tne = {x=  1,y=  1,z=  1}
			neighborhood.tse = {x=  1,y=  1,z= -1}
			neighborhood.tsw = {x= -1,y=  1,z= -1}
			neighborhood.tnw = {x= -1,y=  1,z=  1}		
			neighborhood.bne = {x=  1,y= -1,z=  1}
			neighborhood.bse = {x=  1,y= -1,z= -1}
			neighborhood.bsw = {x= -1,y= -1,z= -1}
			neighborhood.bnw = {x= -1,y= -1,z=  1}
		end
	end	
	
	--loop through cell list
	for pos_hash,v in next, automata.patterns[pattern_id].cell_list do
		local same_count = 0
		local pos = minetest.get_position_from_hash(pos_hash) --@todo, figure out how to add / subtract hashes
		for k, offset in next, neighborhood do
			--add the offsets to the position @todo although this isn't bad
			local npos = {x=pos.x+offset.x, y=pos.y+offset.y, z=pos.z+offset.z}
			--look in the cell list
			if automata.patterns[pattern_id].cell_list[minetest.hash_node_position(npos)] then
				same_count = same_count +1
			else
				empty_neighbors[minetest.hash_node_position(npos)] = true
			end
		end
		--now we have a same neighbor count, apply life and death rules
		local gpos = {}
		--minetest.log("action", "rules.survive: "..rules.survive..", same_count: "..same_count)
		if string.find(rules.survive, same_count) then
			--add to life list
			gpos = {x=pos.x+growth_offset.x, y=pos.y+growth_offset.y, z=pos.z+growth_offset.z}
			
			if rules.grow_distance ~= 0 then
				table.insert(life_list, gpos) --when node is actually set we will add to new_cell_list
				table.insert(death_list, pos) --with grow_distance ~= 0, the old pos dies leaving rules.trail
			else
				--in the case that this is the final iteration, we need to pass it to the life list afterall
				if is_final == 1 then
					table.insert(life_list, pos) --when node is actually set we will add to new_cell_list
				else
					new_cell_list[pos_hash] = true --if grow_distance==0 we just let it be but add to new_cell_list
					--oh, we also have to test it against the pmin and pmax
					for k,v in next, pos do
						if pos[k] < new_pmin[k] then new_pmin[k] = pos[k] end
						if pos[k] > new_pmax[k] then new_pmax[k] = pos[k] end
					end
				end
			end
			
		else
			--add to death list, regardless of grow_distance setting
			table.insert(death_list, pos)
		end
	end
	--loop through the new total neighbors list
	for epos_hash,v in next, empty_neighbors do
		local same_count = 0
		local epos = minetest.get_position_from_hash(epos_hash)
		for k, offset in next, neighborhood do
			--add the offsets to the position @todo although this isn't bad
			local npos = {x=epos.x+offset.x, y=epos.y+offset.y, z=epos.z+offset.z}
			--look in the cell list
			if automata.patterns[pattern_id].cell_list[minetest.hash_node_position(npos)] then
				same_count = same_count +1
			end
		end
		local bpos = {}
		--minetest.log("action", "rules.birth: "..rules.birth..", same_count: "..same_count)
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
		if is_final == 1 then
			minetest.set_node(bpos, {name=rules.final})
		else
			minetest.set_node(bpos, {name="automata:active"})
			--add to cell_list
			--minetest.log("action", "bpos: "..dump(bpos))
			new_cell_list[minetest.hash_node_position(bpos)] = true
			for k,v in next, bpos do
				if bpos[k] < new_pmin[k] then new_pmin[k] = bpos[k] end
				if bpos[k] > new_pmax[k] then new_pmax[k] = bpos[k] end
			end
		end
	end
	
	if is_final == 1 or next(new_cell_list) == nil then
		--remove the pattern from the registry
		print(string.format("pattern, "..pattern_id.." iteration #"..automata.patterns[pattern_id].iteration.." elapsed time: %.2fms (completed)", (os.clock() - t1) * 1000))
		minetest.chat_send_player(automata.patterns[pattern_id].creator, "pattern# "..pattern_id.." just completed at gen "..automata.patterns[pattern_id].iteration)
		automata.patterns[pattern_id] = nil
	else
		--update the pattern values: pmin, pmax, cell_count, cell_list
		automata.patterns[pattern_id].pmin = new_pmin
		automata.patterns[pattern_id].pmax = new_pmax
		local ccount = 0
		for k,v in next, new_cell_list do
			ccount = ccount +1
		end
		automata.patterns[pattern_id].cell_count = ccount
		automata.patterns[pattern_id].cell_list = new_cell_list
		print(string.format("pattern, "..pattern_id.." iteration #"..automata.patterns[pattern_id].iteration.." elapsed time: %.2fms (new count: "..ccount..")", (os.clock() - t1) * 1000))
	end
	
	return true
end

--[[
METHOD: automata.validate(pname)
RETURN: rule_id (a reference to the automata.rule_registry)
DESC: if the rule values are valid, make an entry into the rules table and return the id
      defaults are set to be Conway's Game of Life
TODO: heavy development of the formspec expected
--]]
function automata.rules_validate(pname, rule_override)
	local rules = {}
	 --minetest.log("action", "here :"..dump(fields))
	--read the player settings to get the last tab and then validate the fields relevant for that tab
	local tab = automata.get_player_setting(pname, "tab")
	
	--regardless we validate the growth options common to 1D, 2D and 3D automata
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if not gens then rules.gens = 100
	elseif tonumber(gens) > 0 and tonumber(gens) < 1001 then rules.gens = tonumber(gens)
	else automata.show_popup(pname, "Generations must be between 1 and 1000-- you said: "..gens) return false end
	
	--trail
	local trail = automata.get_player_setting(pname, "trail")
	if not trail then rules.trail = "air" 
	elseif minetest.get_content_id(trail) ~= 127 then rules.trail = trail; print(minetest.get_content_id(trail))
	else automata.show_popup(pname, trail.." is not a valid block type") return false end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then rules.final = "stone" 
	elseif minetest.get_content_id(final) ~= 127 then rules.final = final
	else automata.show_popup(pname, final.." is not a valid block type") return false end
	
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then rules.destruct = "false" 
	else rules.destruct = destruct end
	
	--then validate fields common to 1D and 2D and importing 2D .LIF files (tab 4)
	if tab == "1" or tab == "2" or tab == "4" then
		
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then rules.grow_distance = 0
		elseif tonumber(grow_distance) then rules.grow_distance = tonumber(grow_distance) --@todo take modf()
		else automata.show_popup(pname, "the grow distance needs to be an integer-- you said: "..grow_distance) return false end
		
		--grow_axis (for 2D implies the calculation plane, for 1D cannot be the same as "axis")
		local grow_axis = automata.get_player_setting(pname, "grow_axis")
		if not grow_axis then rules.grow_axis = "y" --with the dropdown on the form this default should never be used
		else rules.grow_axis = grow_axis end
	end
	
	--fields specific to 1D
	if tab == "1"  then
		rules.neighbors = 2 --implied (neighbors is used by grow() to determine dimensionality)
		
		--code1d (must be between 1 and 256 -- NKS rule numbers for 1D automata)
		local code1d = automata.get_player_setting(pname, "code1d")
		if not code1d then rules.code1d = 30 
		elseif code1d > 0 and code1d <= 256 then rules.code1d = code1d
		else automata.show_popup(pname, "the 1D rule should be between 1 and 256-- you said: "..code1d) return false end
		
		--axis (this is the calculation axis and must not be the same as the grow_axis, only matters if tab=1)
		local axis = automata.get_player_setting(pname, "axis")
		if not axis then rules.axis = "x"  --with the dropdown on the form this default should never be used
		else rules.axis = axis end
		
		if axis == grow_axis then automata.show_popup(pname, "the grow axis and main axis cannot be the same") return false end
		
	end
	
	--fields specific to 2D
	if tab == "2" then
		--n2d
		local n2d = automata.get_player_setting(pname, "n2d")
		if not n2d then rules.neighbors = 8 --with the dropdown on the form this default should never be used
		else rules.neighbors = tonumber(n2d) end
		
		--code2d (must be in the format survive/birth, ie, 23/3)
		local code2d = automata.get_player_setting(pname, "code2d")
		if not code2d then rules.survive = "23"; rules.birth = "3" 
		else
			local split
			split = string.find(code2d, "/")
			if split then
				-- take the values to the left and the values to the right
				rules.survive = string.sub(code2d, 1, split-1)
				rules.birth = string.sub(code2d, split+1)
			else
				automata.show_popup(pname, "the rule code should be in the format \"23/3\"-- you said: "..code2d) return false
			end
		end
	end
	
	--fields specific to 3D
	if tab == "3" then
		--n3d
		local n3d = automata.get_player_setting(pname, "n3d")
		if not n3d then rules.neighbors = 26 --with the dropdown on the form this default should never be used
		else rules.neighbors = tonumber(n3d) end
		
		--code3d (must be in the format survive/birth, ie, 23/3)
		local code3d = automata.get_player_setting(pname, "code3d")
		if not code3d then rules.survive = "23"; rules.birth = "3" 
		else
			local split
			split = string.find(code3d, "/")
			if split then
				-- take the values to the left and the values to the right
				rules.survive = string.sub(code3d, 1, split-1)
				rules.birth = string.sub(code3d, split+1)
			else
				automata.show_popup(pname, "the rule code should be in the format \"2,3,18/3,14\"-- you said: "..code3d) return false
			end
		end
	end
	
	if tab == "4" then
		--assume neighbors - 8
		rules.neighbors = 8
		--process the rule override if passed in to rules_validate() as "rule_override"
		if rule_override then
			local split
			split = string.find(rule_override, "/")
			if split then
				-- take the values to the left and the values to the right
				rules.survive = string.sub(rule_override, 1, split-1)
				rules.birth = string.sub(rule_override, split+1)
			else
				minetest.log(error, "something was wrong with #R line in the .lif file"..automata.lifs[lif_id]..".LIF") return false
			end
		else
			--otherwise standard game of life rules
			rules.survive = "23"
			rules.birth = "3"
		end
	end
	minetest.log("action","rules: "..dump(rules))
	return rules
end

--[[
METHOD: automata.new_pattern(pname, offset_list)
RETURN: true/false
DESC: calls rules_validate() can activate inactive_cells or initialize from a list
TODO: heavy development of the formspec expected
--]]
function automata.new_pattern(pname, offsets, rule_override)
	-- form validation
	local rules = automata.rules_validate(pname, rule_override) --will be false if rules don't validate
	
	minetest.log("action", "rules after validate: "..dump(rules))
	
	if rules then --in theory bad rule settings in the form should fail validation and throw a popup
		--create the new pattern id empty
		table.insert(automata.patterns, true) --placeholder to get id
		local pattern_id = #automata.patterns
		local pos = {}
		local pmin, pmax = {}
		local hashed_cells = {}
		local cell_count=0
		
		--are we being supplied with a list of offsets?
		if offsets then
			local player = minetest.get_player_by_name(pname)
			local ppos = player:getpos()
			ppos = {x=math.floor(ppos.x), y=math.floor(ppos.y), z=math.floor(ppos.z)} --remove decimals
			--minetest.log("action", "rules: "..dump(rules))
			for k,offset in next, offsets do
				local cell = {}
				if rules.grow_axis == "x" then
					cell = {x = ppos.x, y=ppos.y+offset.n, z=ppos.z+offset.e}
				elseif rules.grow_axis == "y" then 
					cell = {x = ppos.x+offset.e, y=ppos.y, z=ppos.z+offset.n}
				elseif rules.grow_axis == "z" then
					cell = {x = ppos.x-offset.e, y=ppos.y+offset.n, z=ppos.z}
				else --3D, no grow_axis
					cell = ppos
				end
				hashed_cells[minetest.hash_node_position(cell)] = true
			end
		else
			hashed_cells = automata.inactive_cells
		end
		
		
		--activate all inactive nodes @todo handle this with voxelmanip
		for pos_hash,_ in pairs(hashed_cells) do --@todo check ownership of node? lock registry?
			pos = minetest.get_position_from_hash(pos_hash)
			minetest.set_node(pos, {name="automata:active"})
			--cell_list[pos_hash] = true --why do this one cell at a time?
			--wipe the inactive cell registry
			--automata.inactive_cells[pos_hash] = nil -- might not need this with after_destruct()
			cell_count = cell_count + 1
			
			if next(pmin) then
				for k,v in next, pos do
					if pos[k] < pmin[k] then pmin[k] = pos[k] end
					if pos[k] > pmax[k] then pmax[k] = pos[k] end
				end
			else
				pmin = pos
				pmax = pos
			end
		end
		
		--add the cell list to the active cell registry with the gens, rules hash, and cell list
		local values = {creator=pname, iteration=0, last_cycle=0, rules=rules, pmin=pmin, pmax=pmax, cell_count=cell_count, cell_list=hashed_cells}
		automata.patterns[pattern_id] = values --overwrite placeholder
		
		--automata.save_patterns_to_file() --PERSISTENCE: not working
		
	end
	return true
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
			--automata.save_patterns_to_file() --PERSISTENCE: this isn't working
		end
	timer = 0
	end
end)

-- a generic node type for active cells
minetest.register_node("automata:active", {
	description = "Active Automaton",
	tiles = {"active.png"},
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
	
	on_construct = function(pos) --@todo this is not getting called by worldedit 
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "\"Inactive Automata\"")
		--register the cell in the cell registry
		automata.inactive_cells[minetest.hash_node_position(pos)] = true
		--minetest.log("action", "inactive: "..dump(automata.inactive_cells))
	end,
	on_dig = function(pos)
		--remove from the inactive cell registry
		if automata.inactive_cells[minetest.hash_node_position(pos)] then
			automata.inactive_cells[minetest.hash_node_position(pos)] = nil end
		--minetest.log("action", "inactive: "..dump(automata.inactive_cells))
		minetest.set_node(pos, {name="air"})
		--automata.save_patterns_to_file() --PERSISTENCE this isn't working
		return true
	end,
})

-- an activated automata block -- further handling of this node done by globalstep
minetest.register_node("automata:active", {
	description = "Active Automata",
	tiles = {"active.png"},
	drop = { max_items = 1, items = { "automata.inactive" } }, -- change back to inactive when dug 
	light_source = 5,
	groups = {live_automata = 1, oddly_breakable_by_hand=1, not_in_creative_inventory=1},
	on_dig = function(pos)
		--get the pattern ID from the meta and remove the cell from the pattern table
		for pattern_id,values in next, automata.patterns do
			for pos_hash,v in next, values.cell_list do
				if minetest.hash_node_position(pos) == pos_hash then
					automata.patterns[pattern_id].cell_list[minetest.hash_node_position(pos)]= nil
					--@todo update the cell count and the pmin and pmax
				end
			end
		end
		minetest.set_node(pos, {name="air"})
		return true
	end,
})

-- the controller for activating cells
minetest.register_tool("automata:remote" , {
	description = "Automata Trigger",
	inventory_image = "remote.png",
	--left-clicking the tool
	on_use = function (itemstack, user, pointed_thing)
		local pname = user:get_player_name()
		automata.show_rc_form(pname)
	end,
})

-- Processing the form from the RC
minetest.register_on_player_receive_fields(function(player, formname, fields)
	minetest.log("action", "fields submitted: "..dump(fields))
	local pname = player:get_player_name()
	
	--detect tab change but save all fields on every update including quit
	local old_tab = automata.get_player_setting(pname, "tab")
	automata.update_settings(pname, fields)
	if old_tab and old_tab ~= automata.get_player_setting(pname, "tab") then
		automata.show_rc_form(pname)
	end	
	
	--this is the only situation where a exit ~= "" should open a form
	if formname == "automata:popup" then
		if fields.exit == "Back" then
			automata.show_rc_form(pname)
		end
	end
	
	if formname == "automata:rc_form" then 
		
		--actual form submissions
		if fields.exit == "Activate" then
			if automata.new_pattern(pname) then
				automata.inactive_cells = {} --reset the inactive cell lsit
				minetest.chat_send_player(pname, "You activated all inactive cells!")
			end
		elseif fields.exit == "Import" then
			if automata.import_lif(pname) then
				minetest.chat_send_player(pname, "You imported a LIF to your current location!")
			end
		elseif fields.exit == "Single" then
			if automata.singlenode(pname) then
				minetest.chat_send_player(pname, "You started a single cell at your current location!")
			end
		end
	end
	
end)

--the formspecs and related settings / selected field variables
automata.player_settings = {} --per player form persistence
automata.lifs = {} --indexed table of lif names
automata.lifnames = "" --string of all lif file names
--this is run at load time (see EOF)
function automata.load_lifs()
	local lifsfile = io.open(minetest.get_modpath("automata").."/lifs/_list.txt", "r")
	if lifsfile then
		for line in lifsfile:lines() do
			if line ~= "" then
			table.insert(automata.lifs, line)
			end
		end
		lifsfile:close()
	end

	for k,v in next, automata.lifs do
		automata.lifnames = automata.lifnames .. v .. ","
	end
end
--every time a form button, select, dropdown or tab is pressed, all settings must be updated.
function automata.update_settings(pname, fields)
	if not automata.player_settings[pname] then automata.player_settings[pname] = {} end
	
	for k,v in next, fields do
		if v ~= "" then
			automata.player_settings[pname][k] = v --we will preserve field entries exactly as entered 
		end
	end
	minetest.log("action", "player settings: "..dump(automata.player_settings[pname]))
end

function automata.get_player_setting(pname, setting)
	
	if automata.player_settings[pname] then
		--minetest.log("action", "line: 550")
		if automata.player_settings[pname][setting] then
			--minetest.log("action", "line: 552")
			--minetest.log("action", "tab: "..automata.player_settings[pname][setting])
			if automata.player_settings[pname][setting] ~= "" then
				--minetest.log("action", "line: 554")
				return automata.player_settings[pname][setting]
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end

function automata.show_rc_form(pname)
	
	local tab = automata.get_player_setting(pname, "tab")
	if not tab then 
		tab = "2"
		automata.player_settings[pname] = {tab=tab}
	end
	
	minetest.log("action", "tab: "..tab)
	
	--load the default fields for the forms
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if not gens then gens = "" end
	--trail
	local trail = automata.get_player_setting(pname, "trail")
	if not trail then trail = "" end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then final = "" end
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then destruct = "false" end
	
	--set some formspec sections for re-use on all tabs
	local f_header = 			"size[12,10]" ..
								"tabheader[0,0;tab;1D, 2D, 3D, Import, Manage;"..tab.."]"
	
	--1D, 2D, 3D, Import
	local f_grow_settings = 	"field[1,4;4,1;trail;Trail Block (eg: default:dirt);"..trail.."]" ..
								"field[1,5;4,1;final;Final Block (eg: default:mese);"..final.."]" ..
								"checkbox[1,6;destruct;Destructive?;"..destruct.."]"..
								"field[3,6;2,1;gens;Generations (eg: 30);"..gens.."]"
	--1D,2D,and 3D
	--make sure the inactive cell registry is not empty
	local activate_section = 	"label[1,8;No inactive cells in map]"
	if next(automata.inactive_cells) then
		activate_section = 		"label[1,8;Activate inactive cells]"..
								"button_exit[1,9;2,1;exit;Activate]"
	end
	local f_footer = 			activate_section ..
								"label[4.5,8;Start one cell here.]"..
								"button_exit[4.5,9;2,1;exit;Single]"
	
	--then populate defaults common to 1D and 2D (and importing)
	if tab == "1" or tab == "2" or tab == "4" then
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then grow_distance = "" end
		minetest.log("action", "distance: ".. grow_distance)
		
		--grow_axis (for 2D implies the calculation plane, for 1D cannot be the same as "axis")
		local grow_axis_id
		local grow_axis = automata.get_player_setting(pname, "grow_axis")
		if not grow_axis then grow_axis_id = 2
		else 
			local idx = {x=1,y=2,z=3}
			grow_axis_id = idx[grow_axis]
		end
		
		local f_grow_distance = 		"field[1,3;4,1;grow_distance;Grow Distance (-1, 0, 1, 2 ...);"..grow_distance.."]"
		local f_grow_axis = 			"dropdown[0.5,1.5;1,1;grow_axis;x,y,z;"..grow_axis_id.."]"
		
		--fields specific to 1D
		if tab == "1"  then
			--code1d (must be between 1 and 256 -- NKS rule numbers for 1D automata)
			local code1d = automata.get_player_setting(pname, "code1d")
			if not code1d then code1d = "" end
			
			--axis (this is the calculation axis and must not be the same as the grow_axis)
			local axis_id
			local axis = automata.get_player_setting(pname, "axis")
			if not axis then axis_id = 1
			else 
				local idx = {x=1,y=2,z=3}
				axis_id = idx[axis]
			end
			
			local f_code1d = 			"field[3,1;4,1;code1d;Rule# (eg: 30);]"
			local f_axis = 				"dropdown[0.5,0.5;1,1;axis;x,y,z;"..axis_id.."]"
			
			minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_grow_axis .. 
								f_grow_distance .. 
								f_code1d .. f_axis ..
								f_footer
			)
			return true
		--fields specific to 2D and LIF import
		elseif tab == "2" then
			--n2d
			local n2d_id
			local n2d = automata.get_player_setting(pname, "n2d")
			if not n2d then n2d_id = 2
			else 
				local idx = {}; idx["4"]=1; idx["8"]=2
				n2d_id = idx[n2d]
			end
			
			--code2d
			local code2d = automata.get_player_setting(pname, "code2d")
			if not code2d then code2d = "" end
			
			local f_n2d = 				"dropdown[0.5,0.5;2;n2d;4,8;"..n2d_id.."]"
			local f_code2d = 			"field[3,1;4,1;code2d;Rules (eg: 23/3);"..code2d.."]"
			
			
			minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_grow_axis .. 
								f_grow_distance .. 
								f_n2d .. f_code2d ..
								f_footer
			)
			return true
		else --tab == 4
			local lif_id = automata.get_player_setting(pname, "lif_id")
			if not lif_id then lif_id = 1 else lif_id = tonumber(string.sub(lif_id, 5)) end
			minetest.show_formspec(pname, "automata:rc_form", 
									f_header ..
									f_grow_settings ..
									f_grow_axis .. 
									f_grow_distance .. 
									"textlist[8,0;4,7;lif_id;"..automata.lifnames..";"..lif_id.."]"..
									"label[8,8;Import Selected LIF here]"..
									"button_exit[8,9;2,1;exit;Import]"
			)
			return true
		end
	end
	if tab == "3"  then
		--n3d
		local n3d_id
		local n3d = automata.get_player_setting(pname, "n3d")
		if not n3d then n3d_id = 3
		else 
			local idx = {}; idx["6"]=1; idx["18"]=2; idx["26"]=3
			n3d_id = idx[n3d]
		end
		
		--code3d
		local code3d = automata.get_player_setting(pname, "code3d")
		if not code3d then code3d = "" end
		
		local f_n3d = 				"dropdown[0.5,0.5;2;n3d;6,18,26;"..n3d_id.."]"
		local f_code3d = 				"field[3,1;4,1;code3d;Rules (eg: 2,3,24,25/3,14,15,16);"..code3d.."]"
		
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_n3d .. f_code3d ..
								f_footer
		)
		return true
	end
	if tab == "5" then --manage patterns
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..			
								"label[8,8;Pause]"..
								"button_exit[8,9;2,1;exit;Pause]"
		)
		return true
	end
end

function automata.show_popup(pname, message)
	minetest.show_formspec(pname, "automata:popup",
								"size[10,8]" ..
								"button_exit[1,1;2,1;exit;Back]"..
								"label[1,3;"..message.."]"
	)
end

function automata.singlenode(pname)
	
	local offset_list = {}
	table.insert(offset_list, {n=0, e=0}) --no offset, single node, at player's position
	if automata.new_pattern(pname, offset_list) then return true end
end

function automata.import_lif(pname)
		
	local lif_id = automata.get_player_setting(pname, "lif_id")
	if not lif_id then lif_id = 1 else lif_id = tonumber(string.sub(lif_id, 5)) end

	local liffile = io.open(minetest.get_modpath("automata").."/lifs/"..automata.lifs[lif_id]..".LIF", "r")
	if liffile then
		local origin = nil
		local offset_list = {}
		local rule_override = nil
		
		--start parsing the LIF file. ignore all lines except those starting with #R, #P, * or .
		for line in liffile:lines() do
			--minetest.log("action", "line: "..line)
			if string.sub(line, 1,2) == "#R" then
				rule_override = string.sub(line, 4)
				--@todo: further clean up this string? is it in the same format as our rules.code?
			end
			if string.sub(line, 1,2) == "#P" then
				local split = string.find(string.sub(line, 4), " ")
				origin = {e = tonumber(string.sub(line, 4, 3+split)), n = tonumber(string.sub(line, split+4))}
				--minetest.log("action", "temp_origin: "..dump(origin))
			end
			--an origin must be set for any lines to be processed otherwise lif file corrupt
			if string.sub(line, 1,1) == "." or string.sub(line, 1,1) == "*" then
				if origin ~= nil then
					
					for i = 0, string.len(line), 1 do --trying to avoid going past the end of the string
						--read each line into the offset table
						if string.sub(line, i+1, i+1) == "*" then
							table.insert(offset_list, {e=origin.e+i, n=origin.n})
						end
					end
					origin.n = origin.n-1 --so that the next row is using the correct n
				end
			end
		end
		--minetest.log("action", "cells: "..dump(offset_list))
		liffile:close()		
			
		if automata.new_pattern(pname, offset_list, rule_override) then return true end
	end	
	return false
end
	
--[[ PERSISTENCE: this is not working
--at mod load restore persistence files
minetest.log("action", "loading automata rules and patterns from files")

local file = io.open(minetest.get_worldpath().."/rule_registry", "r")
if file then
	for line in file:lines() do
		minetest.log("action", "rules line: "..dump(line))
		if line ~= "" then
			local tline = minetest.deserialize(line)
			automata.rule_registry[tline.key] = tline.values
		end
	end
	file:close()
end
local file = io.open(minetest.get_worldpath().."/patterns", "r")
if file then
	for line in file:lines() do
		minetest.log("action", "patterns line: "..dump(line))
		if line ~= "" then
			local tline = minetest.deserialize(line) -- @todo THIS SUCKS. many sub-tables get dropped!!!!!!!!!!!
			automata.patterns[tline.key] = tline.values
		end
	end
	file:close()
end
minetest.log("action", "rules: "..dump(automata.rule_registry))
minetest.log("action", "patterns: "..dump(automata.patterns)) --]]

--read from file, the list of lifs supplied
automata.load_lifs()