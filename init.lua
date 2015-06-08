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
	--update the pattern values: iteration, last_cycle
	automata.patterns[pattern_id].iteration = automata.patterns[pattern_id].iteration +1
	automata.patterns[pattern_id].last_cycle = automata.current_cycle
	local death_list ={} --cells that will be set to rules.trail at the end of grow()
	local life_list = {} --cells that will be set to automata:active at the end of grow()
	local empty_neighbors = {} --non -active neighbor cell list to be tested for births
	local new_cell_list = {} --the final cell list to transfer back to automata.patterns[pattern_id]
							 -- some of ^ will be cells that survived in a growth=0 ruleset
							 -- ^ this is to save the time of setting nodes for survival cells
	local new_pmin = {x=0,y=0,z=0}
	local new_pmax = {x=0,y=0,z=0}
	--load the rules
	local rules = automata.rule_registry[automata.patterns[pattern_id].rule_id]
	local is_final = 0
	if automata.patterns[pattern_id].iteration == rules.ttl then
		is_final = 1
	end
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

			if rules.growth ~= 0 then
				table.insert(life_list, gpos) --when node is actually set we will add to new_cell_list
				table.insert(death_list, pos) --with growth, the old pos dies leaving rules.trail
			else
				--in the case that this is the final iteration, we need to pass it to the life list afterall
				if is_final == 1 then
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
		minetest.chat_send_player(automata.patterns[pattern_id].creator, "pattern# "..pattern_id.." just completed at gen "..automata.patterns[pattern_id].iteration)
		automata.patterns[pattern_id] = nil
	else
		--update the pattern values: pmin, pmax, cell_count, cell_list
		automata.patterns[pattern_id].pmin = new_pmin
		automata.patterns[pattern_id].pmax = new_pmax
		automata.patterns[pattern_id].cell_count = table.getn(new_cell_list) --@todo not working
		automata.patterns[pattern_id].cell_list = new_cell_list
	end
end

--[[
METHOD: automata.validate(pname, fields)
RETURN: rule_id (a reference to the automata.rule_registry)
DESC: if the rule values are valid, make an entry into the rules table and return the id
      defaults are set to be Conway's Game of Life
TODO: heavy development of the formspec expected
--]]
function automata.rules_validate(pname, fields)
	local rules = {}
	 --minetest.log("action", "here :"..dump(fields))
	
	if not fields.code or fields.code == "" then fields.code = "23/3" end
	local split = string.find(fields.code, "/")
	if split then
		-- take the values to the left and the values to the right @todo validation will be made moot by a stricter form
		rules["survive"] = string.sub(fields.code, 1, split-1)
		rules["birth"] = string.sub(fields.code, split+1)
		
	else
		minetest.chat_send_player(pname, "the rule code should be in the format \"3/23\"; you said: "..fields.code)
		return false
	end
	
	
	
	if not fields.neighbors or fields.neighbors == "" then rules["neighbors"] = 8
	elseif fields.neighbors == "4" or fields.neighbors == "8" then rules["neighbors"] = tonumber(fields.neighbors)
	else minetest.chat_send_player(pname, "neighbors must be 4 or 8; you said: "..fields.neighbors) return false end
	
	if not fields.ttl or fields.ttl == "" then rules["ttl"] = 30
	elseif tonumber(fields.ttl) > 0 and tonumber(fields.ttl) < 101 then rules["ttl"] = tonumber(fields.ttl)
	else minetest.chat_send_player(pname, "Generations must be between 1 and 100; you said: "..fields.ttl) return false end
	
	if not fields.growth or fields.growth == "" then rules["growth"] = 0
	elseif tonumber(fields.growth) then rules["growth"] = tonumber(fields.growth) --@todo: deal with decimals
	else minetest.chat_send_player(pname, "Growth must be an integer; you said: "..fields.growth) return false end
	
	if not fields.plane or fields.plane == "" then rules["plane"] = "y"
	elseif string.len(fields.plane) == 1 and string.find("xyzXYZ", fields.plane) then rules["plane"] = string.lower(fields.plane)
	else minetest.chat_send_player(pname, "Plane must be x, y or z; you said: "..fields.plane) return false end
	
	if not fields.trail or fields.trail == "" then rules["trail"] = "air"
	elseif minetest.get_content_id(fields.trail) then rules['trail'] = fields.trail
	else minetest.chat_send_player(pname, "\""..fields.trail .."\" is not a valid Trail block type") return false end
	
	if not fields.final or fields.final == "" then rules["final"] = "automata:active"
	elseif minetest.get_content_id(fields.final) then rules['final'] = fields.final
	else minetest.chat_send_player(pname, "\""..fields.final .."\" is not a valid Final block type") return false end
	
	rules["creator"] = pname
	
	--add the rule to the rule_registry @todo, need to check to see if this rule is already in the list (checksum?)
	table.insert(automata.rule_registry, rules)
	local rule_id = #automata.rule_registry
	--automata.save_rules_to_file() --PERSISTENCE: this isn't working
	return rule_id
end

--[[
METHOD: automata.new_pattern(pname, fields, initial)
RETURN: true/false
DESC: calls rules_validate() can activate inactive_cells or initialize from a list
TODO: heavy development of the formspec expected
--]]
function automata.new_pattern(pname, fields, offsets)
	-- form validation
	local rule_id = automata.rules_validate(pname, fields) --will be false if rules don't validate
	--minetest.log("action","rule_registered: "..dump(automata.rule_registry[rule_id]))
	if not rule_id then
		minetest.chat_send_player(pname, "Something was wrong with your inputs!")
		return false
	else
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
			local rules = automata.rule_registry[rule_id]
			--minetest.log("action", "rules: "..dump(rules))
			for k,offset in next, offsets do
				local cell = {}
				if rules.plane == "x" then
					cell = {x = ppos.x, y=ppos.y+offset.n, z=ppos.z+offset.e}
				elseif rules.plane == "y" then 
					cell = {x = ppos.x+offset.e, y=ppos.y, z=ppos.z+offset.n}
				elseif rules.plane == "z" then
					cell = {x = ppos.x-offset.e, y=ppos.y+offset.n, z=ppos.z}
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
		
		--add the cell list to the active cell registry with the ttl, rules hash, and cell list
		local values = {creator=pname, iteration=0, last_cycle=0, rule_id=rule_id, pmin=pmin, pmax=pmax, cell_count=cell_count, cell_list=hashed_cells}
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
		automata.show_activation_form(pname)
	end,
})

-- Processing the form from the RC
minetest.register_on_player_receive_fields(function(player, formname, fields)
	minetest.log("action", "fields submitted: "..dump(fields))
	
	local pname = player:get_player_name()
	
	-- activation form submitted or lif file selected
	if formname == "automata:rc_form" then
		--lif file selected
		if not fields.exit and fields.lif_list then
			--set current selection
			automata.player_last_lif[pname] = tonumber(string.sub(fields.lif_list, 5))
			--if double click open popup description
			if string.sub(fields.lif_list, 1,4) == "DCL:" then
				automata.show_lif_desc(pname, fields)
			end
		elseif fields.exit == "Activate" then
			if automata.new_pattern(pname, fields) then
				automata.inactive_cells = {} --reset the inactive cell lsit
				minetest.chat_send_player(pname, "You activated all inactive cells!")
			end
		elseif fields.exit == "Import" then
			if automata.import_lif(pname, fields) then
				minetest.chat_send_player(pname, "You imported a LIF to your current location!")
			end
		elseif fields.exit == "Single" then
			if automata.singlenode(pname,fields) then
				minetest.chat_send_player(pname, "You started a single cell at your current location!")
			end
		end
	end
	
	-- lif detail screen closed if Close then back to form2, if Import then import_lif()
	if formname == "automata:rc_lif_desc" then
		if fields.exit == "Back" then
			automata.show_activation_form(pname)
		end
	end
	
end)

--the formspecs and related settings / selected field variables
automata.player_last_lif = {}
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

function automata.show_activation_form(pname)
	local lifidx = 1
	if automata.player_last_lif[pname] ~= nil then
		lifidx = automata.player_last_lif[pname]
	end
	--make sure the inactive cell registry is not empty
	local activate_section = "label[1,8;No inactive cells in map]"
	if next(automata.inactive_cells) then
		activate_section = "label[1,8;Activate inactive cells]"..
			"button_exit[1,9;2,1;exit;Activate]"
	else
		
	end
	minetest.show_formspec(pname, "automata:rc_form", 
			"size[12,10]" ..
			"field[1,1;2,1;neighbors;N(4 or 8);]" ..
			"field[3,1;4,1;code;Rules (eg: 23/3);]" ..
			
			"field[1,2;4,1;plane;Plane (x, y, or z);]" ..
			"field[1,3;4,1;growth;Growth (-1, 0, 1, 2 ...);]" ..
			"field[1,4;4,1;trail;Trail Block (eg: default:dirt);]" ..
			"field[1,5;4,1;final;Final Block (eg: default:mese);]" ..
			"field[1,6;4,1;ttl;Generations (eg: 30);]" ..
			
			"textlist[8,0;4,7;lif_list;"..automata.lifnames..";"..lifidx.."]"..activate_section..
			
			"label[4.5,8;Start one cell here.]"..
			"button_exit[4.5,9;2,1;exit;Single]"..
			
			"label[8,8;Import Selected LIF here]"..
			"button_exit[8,9;2,1;exit;Import]"
	)
end

function automata.show_lif_desc(pname,fields)
	local lifidx = automata.player_last_lif[pname]
	local liffile = io.open(minetest.get_modpath("automata").."/lifs/"..automata.lifs[lifidx]..".LIF", "r")
	if liffile then
		local message = ""
		for line in liffile:lines() do
			if string.sub(line, 1,2) == "#D" then
				message = message .. string.sub(line, 4) .. "\n"
			end
			
		end
		minetest.show_formspec(pname, "automata:rc_lif_desc",
			"size[10,8]" ..
			"button_exit[1,1;2,1;exit;Back]"..
			"textarea[1,3;9,6;desc;"..automata.lifs[lifidx]..";"..minetest.formspec_escape(message).."]"
		)
		liffile:close()
	end
end

function automata.singlenode(pname,fields)
	
	local offset_list = {}
	table.insert(offset_list, {n=0, e=0}) --no offset, single node, at player's position
	if automata.new_pattern(pname, fields, offset_list) then return true end
end

function automata.import_lif(pname, fields)
		
	local lifidx = 1
	if automata.player_last_lif[pname] then
		lifidx=automata.player_last_lif[pname]
	end
	local liffile = io.open(minetest.get_modpath("automata").."/lifs/"..automata.lifs[lifidx]..".LIF", "r")
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
		
		if fields.code == "" and rule_override then fields.code = rule_override end
		if automata.new_pattern(pname, fields, offset_list) then return true end
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