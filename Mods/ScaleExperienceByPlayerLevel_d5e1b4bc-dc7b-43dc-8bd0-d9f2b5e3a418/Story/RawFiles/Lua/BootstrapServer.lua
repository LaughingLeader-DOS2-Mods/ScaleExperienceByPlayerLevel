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

local function printd(msg, ...)
	Ext.Print(string.format(msg, ...))
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

---@return integer
local function GetPartyLevel()
	local level = 1
	for i,v in pairs(Osi.DB_IsPlayer:Get(nil)) do
		local plevel = CharacterGetLevel(v[1])
		if plevel and plevel > level then
			level = plevel
		end
	end
	return level
end

---@param character EsvCharacter
function GrantPartyExperience(character, printDebug)
	ObjectSetFlag(character.MyGuid, "LLXPSCALE_GrantedExperience", 0)
	--print("GrantPartyExperience", character.MyGuid, character.Stats.Name)
	local gain = Ext.StatGetAttribute(character.Stats.Name, "Gain") or 0
	if gain == "None" then
		gain = 0
	elseif gain ~= 0 then
		gain = tonumber(gain)
	end
	if gain > 0 then
		-- Apparently Larian subtracts the character gain by 1, so 6 (125xp) is really 5 (100xp). 1 becomes "Bone".
		gain = gain - 1
	end
	if Mods.LeaderLib then
		local settings = Mods.LeaderLib.SettingsManager.GetMod("d5e1b4bc-dc7b-43dc-8bd0-d9f2b5e3a418", false)
		if settings then
			local gainModifier = settings.Global:GetVariable("GainModifier", 1.0)
			if gainModifier ~= 1.0 then
				gain = Ext.Round((gain * gainModifier) + 0.25)
			end
		end
	end
	if gain > 0 then
		local xpLevel = character.Stats.Level
		local scaleLowerLevels = GlobalGetFlag("LLXPSCALE_AlwaysScaleToPlayerLevelEnabled") == 1

		local plevel = GetPartyLevel()
		if plevel < xpLevel then
			xpLevel = plevel
		elseif scaleLowerLevels and xpLevel < plevel then
			xpLevel = plevel
		end

		if printDebug then
			printd("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Granting experience to all players scaled by (%s) Gain at level (%s). Dying character: (%s)[%s]", gain, xpLevel, character.DisplayName, character.MyGuid)
		end

		--local partyStructure,highestLevel = BuildPartyStructure()
		local leader = CharacterGetHostCharacter()
		PartyAddExperience(leader, 1, xpLevel, gain)
	else
		if printDebug then
			printd("[LLXPSCALE:BootstrapServer.lua:LLXPSCALE_Ext_GrantExperience] Skipping experience for %s since Gain is 0.", character.MyGuid)
		end
	end
	return false
end

local function GetCombatID(uuid)
	local combatid = CombatGetIDForCharacter(uuid) or -1
	if not combatid or combatid <= 0 then
		local db = Osi.DB_CombatCharacters:Get(uuid, nil)
		if db and #db > 0 then
			combatid = db[1][2]
		end
	end
	if not combatid or combatid <= 0 then
		local db = Osi.DB_WasInCombat:Get(uuid, nil)
		if db and #db > 0 then
			combatid = db[1][2]
		end
	end
	Ext.Print(uuid, combatid)
	return combatid
end

---@param character EsvCharacter
local function IsInCombatWithPlayer(character, attackOwner)
	if attackOwner and CharacterIsPlayer(attackOwner) == 1 then
		return true
	end
	local combatid = GetCombatID(character.MyGuid)
	if combatid > 0 then
		for i,db in pairs(Osi.DB_IsPlayer:Get(nil)) do
			if GetCombatID(db[1]) == combatid then
				return true
			end
		end
	end
	return false
end

-- Ext.RegisterOsirisListener("CharacterStatusApplied", 3, "after", function(char, status, source)
-- 	if status == "SUMMONING" then
-- 		local character = Ext.GetCharacter(char)
-- 		print(character.Summon, character.Stats.IsPlayer, character.IsPlayer, CharacterIsSummon(character.MyGuid))
-- 	end
-- end)

---@param character EsvCharacter
local function IsHostileToPlayer(character)
	local faction = GetFaction(character.MyGuid) or ""
	if string.find(faction, "Evil") or GlobalGetFlag("LLXPSCALE_IgnoreEnemyAlignmentEnabled") == 1 then
		return true
	end
	for i,db in pairs(Osi.DB_IsPlayer:Get(nil)) do
		if CharacterIsEnemy(db[1], character.MyGuid) == 1 then
			return true
		end
	end
	return false
end

---@param character EsvCharacter
---@param skipAlignmentCheck boolean|nil
local function CanGrantExperience(character, skipAlignmentCheck)
	if GlobalGetFlag("LLXPSCALE_DeathExperienceDisabled") == 1 or 
	(character.RootTemplate 
	and character.RootTemplate.DefaultState ~= 0 -- Dead is > 0
	and not IsInCombatWithPlayer(character))
	then
		return false
	end
	return not character:HasTag("NO_RECORD") -- A corpse?
	and not character:HasTag("LLXPSCALE_DisableDeathExperience")
	and ObjectGetFlag(character.MyGuid, "LLXPSCALE_GrantedExperience") == 0
	and not character.Resurrected
	--and not character.IsPlayer
	and CharacterIsPlayer(character.MyGuid) == 0
	--and not character.Summon
	and CharacterIsSummon(character.MyGuid) == 0
	--and not character.PartyFollower
	and CharacterIsPartyFollower(character.MyGuid) == 0
	and not character:HasTag("LeaderLib_Dummy")
	and not character:HasTag("LEADERLIB_IGNORE")
	--and not string.find(character.DisplayName, "Dead")
	--and not string.find(character.DisplayName, "Corpse")
	and (skipAlignmentCheck == true or IsHostileToPlayer(character))
end

local isGameLevel = true
local isDebugMode = Ext.IsDeveloperMode() == true

Ext.RegisterOsirisListener("GameStarted", 2, "after", function(region, _)
	isGameLevel = IsGameLevel(region) == 1
end)

Ext.RegisterOsirisListener("CharacterDied", 1, "before", function(char)
	if isGameLevel and Ext.GetGameState() == "Running" then
		local character = Ext.GetCharacter(char)
		if character ~= nil and CanGrantExperience(character) and IsInCombatWithPlayer(character) then
			local b,err = xpcall(GrantPartyExperience, debug.traceback, character, isDebugMode)
			if not b then
				Ext.PrintError(err)
			end
		elseif isDebugMode then
			if CombatGetIDForCharacter(CharacterGetHostCharacter()) ~= 0 then
				printd("[LLXPSCALE:CharacterDied] Character (%s)[%s] can't grant experience. DefaultState(%s)", character and character.DisplayName or "", char, (character.RootTemplate and character.RootTemplate.DefaultState) or "?")
			end
		end
	end
end)

Ext.RegisterOsirisListener("CharacterKilledBy", 3, "after", function(victim, attackOwner, attacker)
	if isGameLevel and Ext.GetGameState() == "Running" then
		local character = Ext.GetCharacter(victim)
		if character ~= nil and CanGrantExperience(character, true) and IsInCombatWithPlayer(character, attackOwner) then
			local b,err = xpcall(GrantPartyExperience, debug.traceback, character, isDebugMode)
			if not b then
				Ext.PrintError(err)
			end
		elseif isDebugMode then
			printd("[LLXPSCALE:CharacterDied] Character (%s)[%s] can't grant experience.", character and character.DisplayName or "", victim)
		end
	end
end)