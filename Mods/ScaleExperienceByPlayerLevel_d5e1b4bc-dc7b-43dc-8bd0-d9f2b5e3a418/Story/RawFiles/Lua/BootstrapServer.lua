Ext.Require("Shared.lua")

local _DEBUG = Ext.Debug.IsDeveloperMode() == true

local _format = string.format
local function printd(msg, ...)
	if _DEBUG then
		Ext.Utils.Print(_format(msg, ...))
	end
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
	local gain = Ext.Stats.GetAttribute(character.Stats.Name, "Gain") or 0
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
		local settings = Mods.LeaderLib.SettingsManager.GetMod(ModuleUUID, false)
		if settings then
			local gainModifier = settings.Global:GetVariable("GainModifier", 1.0)
			if gainModifier ~= 1.0 then
				gain = Ext.Utils.Round((gain * gainModifier) + 0.25)
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
	if uuid == nil then
		return nil
	end
	local combatid = CombatGetIDForCharacter(uuid) or -1
	if not combatid or combatid <= 0 then
		local db = Osi.DB_CombatCharacters:Get(uuid, nil)
		if db and db[1] then
			combatid = db[1][2]
		end
	end
	if not combatid or combatid <= 0 then
		local db = Osi.DB_WasInCombat:Get(uuid, nil)
		if db and db[1] then
			combatid = db[1][2]
		end
	end
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

Ext.Osiris.RegisterListener("GameStarted", 2, "after", function(region, _)
	isGameLevel = IsGameLevel(region) == 1
end)

Ext.Osiris.RegisterListener("CharacterDied", 1, "before", function(char)
	if isGameLevel and Ext.GetGameState() == "Running" and ObjectExists(char) == 1 then
		local character = Ext.GetCharacter(char)
		if character ~= nil and CanGrantExperience(character) and IsInCombatWithPlayer(character) then
			local b,err = xpcall(GrantPartyExperience, debug.traceback, character, _DEBUG)
			if not b then
				Ext.PrintError(err)
			end
		elseif _DEBUG and ObjectGetFlag(char, "LLXPSCALE_GrantedExperience") == 0 then
			if CombatGetIDForCharacter(CharacterGetHostCharacter()) ~= 0 then
				printd("[LLXPSCALE:CharacterDied] Character (%s)[%s] can't grant experience. DefaultState(%s)", character and character.DisplayName or "", char, (character.RootTemplate and character.RootTemplate.DefaultState) or "?")
			end
		end
	end
end)

Ext.Osiris.RegisterListener("CharacterKilledBy", 3, "after", function(victim, attackOwner, attacker)
	if isGameLevel and Ext.GetGameState() == "Running" and ObjectExists(victim) == 1 then
		local character = Ext.Entity.GetCharacter(victim)
		if character ~= nil and CanGrantExperience(character, true) and IsInCombatWithPlayer(character, attackOwner) then
			local b,err = xpcall(GrantPartyExperience, debug.traceback, character, _DEBUG)
			if not b then
				Ext.Utils.PrintError(err)
			end
		elseif _DEBUG and ObjectGetFlag(character.MyGuid, "LLXPSCALE_GrantedExperience") == 0 then
			printd("[LLXPSCALE:CharacterDied] Character (%s)[%s] can't grant experience.", character and character.DisplayName or "", victim)
		end
	end
end)