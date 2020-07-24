---@param key string
---@param fallback number
---@param toInt boolean
---@return number
local function GetExtraDataValue(key, fallback, toInt)
	local val = Ext.ExtraData[key]
	if val ~= nil then
		if toInt == true then
			return math.tointeger(val)
		else
			return val
		end
	end
	return fallback
end

function LLXPSCALE_Ext_GetScaledExperience(gain, level)
	local levelCap = math.floor(GetExtraDataValue("LevelCap", 35))
	if gain ~= nil and gain > 0 then
		if Ext.IsDeveloperMode() then Ext.Print("[LLXPSCALE:BootstrapClient.lua:GetScaledExperience] gain(" .. tostring(gain) .. ") level(" .. tostring(level) .. "/".. tostring(levelCap) ..")") end
		if levelCap == nil or levelCap <= 0 then levelCap = 1 end
		if level >= levelCap then return 0 end

		local quadBaseActPart = level
		if level > 8 then quadBaseActPart = 8 end
		local quadraticActPart = level - quadBaseActPart;
		local actPartQuad = quadBaseActPart * (quadBaseActPart + 1)
		local actMod = 0.0
		if quadraticActPart > 0 then
			if quadraticActPart == 2 then
				actMod = 1.9320999;
			else
				actMod = 1.39 ^ quadraticActPart
				local x = (actPartQuad * actMod)
				-- round  x + 0.5 - (x + 0.5) % 1
				actPartQuad = x + 0.5 - (x + 0.5) % 1
			end
		end
		local xp = math.floor((10 * gain * actPartQuad + 24) / 25) * 25

		if Ext.IsDeveloperMode() then 
			Ext.Print("	[BootstrapClient.lua:LLXPSCALE_ExperienceScale] quadBaseActPart(" .. tostring(quadBaseActPart) .. ") quadraticActPart(" .. tostring(quadraticActPart)..") actPartQuad(" .. tostring(actPartQuad)..") actMod(" .. tostring(actMod)..") actPartQuad(" .. tostring(actPartQuad)..")")
			Ext.Print("[BootstrapClient.lua:LLXPSCALE_ExperienceScale] xp(".. tostring(xp) ..")")
		end
		return xp
	end
	return 0
end

local function LLXPSCALE_Client_InitializeModule()
	--- Disables default Gain scaling.
	Ext.StatSetLevelScaling("Character", "Gain", function(gain,level) return 0 end)
	Ext.Print("[LLXPSCALE:BootstrapClient.lua:LLXPSCALE_ModuleLoading] Registered Gain scale override function.")
end

local function LLXPSCALE_Client_ModuleLoading()
	LLXPSCALE_Client_InitializeModule()
end

local function LLXPSCALE_Client_ModuleResume()
	LLXPSCALE_Client_InitializeModule()
end

Ext.RegisterListener("ModuleLoading", LLXPSCALE_Client_ModuleLoading)
Ext.RegisterListener("ModuleResume", LLXPSCALE_Client_ModuleResume)