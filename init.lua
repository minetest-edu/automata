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

-- function to add nodes to the iteration queue
local function enqueue(pos, data)
	--pos is passed as a table but we need it as a string for indexing
	local pos = minetest.pos_to_string(pos)
	--checks to see if the block is already enqueued to change, (first come first served)
	if automata.block_queue[pos] == nil then
		minetest.log("action", "enqueued at pos: "..pos)
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
		-- process the queue
		automata:process_queue()
		timer = 0
		--minetest.log("action", "block_queue: "..dump(automata.block_queue))
		--minetest.log("action", "check_list: "..dump(automata.check_list))
		
		--erase all check_list items from this round of checking and increment
		for k,v in pairs(automata.check_list) do -- just resetting this table each globalstep seems to work too
			if v == automata.check_count then automata.check_list[k]= nil end -- wipe all entries from last check round
		end
		automata.check_count = automata.check_count + 1 
	end
end)

--[[ FOR THE GROWTH OF ACTIVE AUTOMATA BLOCKS --]]

--based on the number of neighbors (5 or 9), the plane, position, and the fingerprint of an automata
--will return the count of same neighbors, and a list of non-same neighbors
local function list_neighbors(pos, neighbors, plane, fingerprint, ttl)
	--minetest.log("action", "neighbors: "..neighbors..", plane: "..plane..", print: "..fingerprint..", ttl: "..ttl)
	local list = {}
	if neighbors == 5 or neighbors == 9 then
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
	if neighbors == 9 then
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
	automata.check_list[minetest.pos_to_string(pos)] = automata.check_count --causing problems
	--minetest.log("action", "count active: "..same_count..", count inactive: "..#inactive_neighbors)
	return same_count, inactive_neighbors
end

--new metadata based grow function
local function grow(pos)
	--first we see if this node has never been checked
	if automata.check_list[minetest.pos_to_string(pos)] ~= automata.check_count then 
		--minetest.log("action", "not already checked")

		local meta			= minetest.get_meta(pos)
		--minetest.log("action", dump(meta:to_table()))
		
		local ttl			= meta:get_int("ttl")
		local fingerprint 	= meta:get_int("fingerprint")
		local binrules 		= meta:get_string("binrules") --trailing zeroes lost if int
		local neighbors 	= meta:get_int("neighbors")
		local growth 		= meta:get_int("growth")
		local plane 		= meta:get_string("plane")
		local trail			= meta:get_string("trail")
		
		--now we must count the neighbors, identify how many are the same and which ones are not
		local same_count, inactive_neighbors = list_neighbors(pos, neighbors, plane, fingerprint, ttl) --marks this node as checked
		
		--survival rules for this node applied
		--minetest.log("action", "before survival rules: "..binrules)
		--minetest.log("action", "newpos before survival rules: "..minetest.pos_to_string(pos))
		if string.sub(binrules, same_count*2+2, same_count*2+2) == "1" then
			
			local newpos = {}
			if     plane == "x" then newpos = {x=pos.x+growth, y=pos.y, z=pos.z}
			elseif plane == "y" then newpos = {x=pos.x, y=pos.y+growth, z=pos.z}
			elseif plane == "z" then newpos = {x=pos.x, y=pos.y, z=pos.z+growth}
			end
			--minetest.log("action", "newpos after survival rules: "..minetest.pos_to_string(newpos))
			
			--if growth is set for this node, then we not only enqueue the next gen, but we set the old block to die
			if growth ~= 0 then enqueue(pos, trail) end --passing a string implies death
			--regardless of growth setting we enqueue the next generation for life
			enqueue(newpos, meta:to_table()) --passing a table implies life
		else
			--if survival fails we enqueue current cell for death
			enqueue(pos, trail) --passing a string implies death
		end
		
		--birth rules for all inactive neighbors checked
		if inactive_neighbors then
			for _,v in pairs(inactive_neighbors) do
				if automata.check_list[minetest.pos_to_string(v)] ~= automata.check_count --already checked
				and automata.block_queue[minetest.pos_to_string(v)] == nil then --already has a destiny
					local sc, _ = list_neighbors(v, neighbors, plane, fingerprint, ttl) --will mark the node as checked
					--based on the birth rules turn this new cell on
					if string.sub(binrules, sc*2+1, sc*2+1) == "1" then
						local newpos = {}
						if     plane == "x" then newpos = {x=v.x+growth, y=v.y, z=v.z}
						elseif plane == "y" then newpos = {x=v.x, y=v.y+growth, z=v.z}
						elseif plane == "z" then newpos = {x=v.x, y=v.y, z=v.z+growth}
						end
						enqueue(newpos, meta:to_table()) --passing a table implies life
					end
				end
			end
		end
	end
	return true --end of the grow function
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

-- automata rule Conway node -- registering this explicitly so that 
minetest.register_node("automata:conway", {
	description = "Conway's Game of Life",
	tiles = {"conway.png"},
	light_source = 5,
	groups = {	live_automata = 1, --abm applied to this group only
				oddly_breakable_by_hand=1,
				--not_in_creative_inventory = 1 --only programmable nodes appear in the inventory
	},
	on_construct = function(pos)
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("nodename", "automata:conway")
		meta:set_string("infotext", "\"Conway's Game of Life\"")
		meta:set_string("binrules", "000001110000000000")
		meta:set_int("neighbors", 9)
		meta:set_int("growth", 1) -- @todo will add this to the formspec
		meta:set_string("plane", "y") -- @todo will add this to the formspec
		meta:set_int("ttl", 50)
		meta:set_string("trail", "air")
		meta:set_string("final", "air") --might not use anymore
		meta:set_int("fingerprint", 1111111) --conway blocks are no use unless they are all the same
	end,
})

-- automata generic growth action for any live automata
minetest.register_abm({
	nodenames = {"group:live_automata"},
	neighbors = {"air"}, --won't grow underground or underwater . . .
	interval = 4,
	chance = 1,
	action = function(pos)
		--minetest.log("action", "grow triggered")
		return grow(pos)
	end,
})

--[[  FOR THE CREATION OF A PROGRAMMABLE BLOCK,
      AND IT'S ACTIVATION AS A LIVE AUTOMATA BLOCK --]]

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

local function nks_rule_convert(nkscode)

	local bits = 0
	local neighbors = string.sub(nkscode, 1, 1) --very important that the nodename starts with "automata:9n" or "automata:5n"
	-- the 5 or 9 neighbor type
	if neighbors ~= "5" and neighbors ~= "9" then
		minetest.log("error", "node name not in correct format for nks_rule_convert()")
		return false
	else
		neighbors = tonumber(neighbors)
	end
	
	-- get the integer code from the nodename
	local code = string.sub(nkscode, 3) --very important that the nodename continues with a code only, no trailing chars
	local intcode = 0
	
	-- also we know that a 5n rule can be no larger than 1023, though a 9n rule can be less than 1024
	if code then intcode = tonumber(code) else return false end
	--minetest.debug("action", "nodename= "..name)
	if not intcode or (neighbors == 5 and intcode > 1023) or (neighbors == 9 and intcode > 262143) then 
		minetest.log("error", "improperly formatted code -- must be in the format 5n2 to 5n1022 or 9n1024 to 9n262142 even only")
		return false
	end
	
	-- convert the integer code to a bigendian binary table
	local bintable = toBits(intcode, neighbors*2)
	--minetest.log("action", table.concat(bintable))
	
	-- test for survival rule 0, which cannot be implemented in this mod
	if bintable[1] == 1 then
		minetest.log("error", "odd-numbered codes are not supported")
		return false
	end
	-- test for single-node growth
	if bintable[2] == 0 then
		minetest.chat_send_all("please note, this code will only die alone")
	end
	local str = ""
	--pass the binary rules back to the node definition
	for i=1,1,1 do
		str = str..bintable[i]
	end
	minetest.log("action", "binstring: "..str)
	local binstring = tostring(table.concat(bintable))
	minetest.log("action", "concat: "..binstring)
	return neighbors, binstring
	
end

-- new block that requires starts inactive and takes input
minetest.register_node("automata:programmable", {
	description = "Programmable Automata",
	tiles = {"dead.png"},
	light_source = 5,
	groups = {oddly_breakable_by_hand=1},
	
	on_construct = function(pos)
		--local n = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[8,8]" ..
				"field[1,1;3,1;text;NKS Code (eg: 5n942);]" ..
				"field[1,2;3,1;plane;Plane (x, y, or z);]" ..
				"field[1,3;3,1;growth;Growth (-1, 0, 1, 2 ...);]" ..
				"field[1,4;3,1;trail;Trail Block (eg: default:dirt);]" ..
				"field[1,5;3,1;final;Final Block (eg: default:mese);]" ..
				"field[1,6;3,1;ttl;Generations (eg: 30);]" ..
				"button_exit[1,7;2,1;exit;Activate]"
		) -- this alone makes the block right-clickable?
		meta:set_string("infotext", "\"Inactive Automata\"")
	end,
	on_receive_fields = function(pos, formname, fields, sender) --or is it this that makes it clickable?
		--print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
		if minetest.is_protected(pos, sender:get_player_name()) then
			minetest.record_protection_violation(pos, sender:get_player_name())
			return
		end
		local meta = minetest.get_meta(pos)
		if not fields.text then return end
		
		minetest.log("action", (sender:get_player_name() or "").." wrote \""..fields.text..
				"\" to programmable automata at "..minetest.pos_to_string(pos))
		meta:set_string("text", fields.text)
		meta:set_string("infotext", '"'..fields.text..'"')
		
		--see if the entered data is a valid NKS rule
		local neighbors, binrules = nks_rule_convert(fields.text)
		if not neighbors or not binrules then 
			minetest.log("error", "neighbors or binrules not returned")
			return false
		end
		
		--convert this block to an Active Automata and set meta
		minetest.set_node(pos, {name="automata:active"})
		--meta = minetest.get_meta(pos) --reload the meta now that we set a new node (not necessary)
		meta:set_string("nodename", "automata:active") --this meta needed so that node never needs to be passed
		meta:set_string("infotext", '"'..fields.text..'"')
		meta:set_string("binrules", binrules)
		meta:set_int("neighbors", neighbors)
		meta:set_int("growth", fields.growth or 1) -- @todo will add this to the formspec
		meta:set_string("plane", fields.plane or "y") -- @todo will add this to the formspec
		meta:set_int("ttl", fields.ttl or 22) -- this sets the limit, counts down each generation / iteration
		meta:set_string("trail", fields.trail or "default:dirt")
		meta:set_string("final", fields.final or "default:dirt") --might not use anymore
		meta:set_int("fingerprint", math.random(1,100000)) --to test which neighbors count as neighbors
	end,
})
