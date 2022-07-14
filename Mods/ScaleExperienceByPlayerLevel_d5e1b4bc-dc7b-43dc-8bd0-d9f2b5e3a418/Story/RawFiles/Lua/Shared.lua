local function DisableGain()
	--- Disables default Gain scaling.
	Ext.Stats.SetLevelScaling("Character", "Gain", function(gain,level) return 0 end)
	--Ext.Utils.Print("[LLXPSCALE:DisableGain] Registered Gain scale override.")
end

Ext.Events.ModuleLoading:Subscribe(DisableGain)
--TODO causes a crash in v56 as of 7/14/2022
--Ext.Events.ModuleResume:Subscribe(DisableGain)