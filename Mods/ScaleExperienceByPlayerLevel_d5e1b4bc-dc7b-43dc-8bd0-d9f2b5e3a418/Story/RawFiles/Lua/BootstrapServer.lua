local function FlattenTable(tbl)
	local result = { }
		
	local function flatten(tbl)
		for _, v in ipairs(tbl) do
			if type(v) == "table" then
				flatten(v)
			else
				table.insert(result, v)
			end
		end
	end
	
	flatten(tbl)
	return result
end

local function PrintIndex(k, indexMap)
	if indexMap ~= nil and type(indexMap) == "table" then
		local displayValue = indexMap[k]
		if displayValue ~= nil then
			return displayValue
		end
	end
	if type(k) == "string" then
		return '"'..k..'"'
	else
		return tostring(k)
	end
end

---Print a value or table (recursive).
---@param o table
---@param indexMap table
---@param innerOnly boolean
---@return string
local function DumpTable(o, indexMap, innerOnly, recursionLevel)
	if recursionLevel == nil then recursionLevel = 0 end
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if innerOnly == true then
				if recursionLevel > 0 then
					s = s .. ' ['..PrintIndex(k, indexMap)..'] = ' .. DumpTable(v, indexMap, innerOnly, recursionLevel + 1) .. ','
				else
					s = s .. ' ['..PrintIndex(k, nil)..'] = ' .. DumpTable(v, indexMap, innerOnly, recursionLevel + 1) .. ','
				end
			else
				s = s .. ' ['..PrintIndex(k, indexMap)..'] = ' .. DumpTable(v, indexMap, innerOnly, recursionLevel + 1) .. ','
			end
		end
		return s .. '} \n'
	else
		return tostring(o)
	end
end

local function BuildPartyStructure(printDebug)
	local players = FlattenTable(Osi.DB_IsPlayer:Get(nil))
	local partyLeaders = {}
	local highestLevel = 1

	if printDebug then 
		Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] Players: (".. DumpTable(players) ..").")
	end

	if #players == 1 then
		local player = CharacterGetHostCharacter()
		local level = CharacterGetLevel(player)
		if printDebug then 
			Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] Only one player ("..player..") at level ("..tostring(level)..")")
		end
		return player,level
	end

	local tableEmpty = true
	for i,v in pairs(players) do
		local level = CharacterGetLevel(v)
		if level > highestLevel then highestLevel = level end
		if tableEmpty then
			if printDebug then 
				Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] partyLeaders count is 0. Adding to table. ("..v..")")
			end
			partyLeaders[v] = {}
			tableEmpty = false
		else
			for leader,members in pairs(partyLeaders) do
				if v ~= leader then
					if CharacterIsInPartyWith(leader, v) == 1 then
						if printDebug then 
							Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] (".. v ..") is in a party with ("..leader..")?")
						end
						members[#members+1] = v
					else
						if printDebug then 
							Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] (".. v ..") is not in a party with ("..leader..")?")
						end
						partyLeaders[v] = {}
					end
				end
			end
		end
	end
	if printDebug then 
		Ext.Print("[LLXPSCALE:BootstrapServer.lua:BuildPartyStructure] Party leader structure: (".. DumpTable(partyLeaders) ..").")
	end
	return partyLeaders,highestLevel
end

---@param char string The UUID of the character that died.
---@param attacker string|nil Attacker's UUID, if any.
function GrantPartyExperience(char, attacker)
	local stats = nil
	local character = Ext.GetCharacter(char)
	if character ~= nil then
		stats = character.Stats.Name
	end
	if stats == nil then stats = GetStatString(char) end
	if stats ~= nil then
		local printDebug = Ext.IsDeveloperMode()
		local gain = Ext.StatGetAttribute(stats, "Gain")
		if gain == "None" then 
			gain = 0 
		else
			gain = tonumber(gain)
		end

		if gain > 0 then
			local enemyLevel = CharacterGetLevel(char)
			if printDebug then
				Ext.Print("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Granting experience to all players scaled by (" .. tostring(gain) ..") gain. ")
			end
			local partyStructure,highestLevel = BuildPartyStructure()
			if GlobalGetFlag("LLXPSCALE_AlwaysScaleToPlayerLevel") == 0 and enemyLevel < highestLevel then
				if printDebug then
					Ext.Print("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] NPC level is lower than party level. Using NPC level for xp scaling. (" .. tostring(highestLevel) .." => "..tostring(enemyLevel)..")")
				end
				highestLevel = enemyLevel
			end
			if type(partyStructure) == "string" then
				PartyAddExperience(partyStructure, 1, highestLevel, gain)
				if printDebug then
					Ext.Print("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Granting xp to sole player (" .. tostring(partyStructure) ..") scaled to level ("..tostring(highestLevel).."). ")
				end
			else
				for leader,members in pairs(partyStructure) do
					PartyAddExperience(leader, 1, highestLevel, gain)
					if printDebug then
						Ext.Print("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Granting xp to party of (" .. tostring(leader) ..") scaled to level ("..tostring(highestLevel).."). ")
					end
					ObjectSetFlag(char, "LLXPSCALE_GrantedExperience", 0)
					return true
				end
			end
		else
			if printDebug then
				Ext.Print("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Skipping experience for (" .. tostring(char) ..") since Gain is 0. ")
			end
		end
	end
	return false
end