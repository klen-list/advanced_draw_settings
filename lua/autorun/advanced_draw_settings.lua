-- By Klen_list

if SERVER then
	local ent_meta = FindMetaTable"Entity"
	local transmitstate = ent_meta.SetPreventTransmit

	do
		local valident = ent_meta.IsValid
		local getclass = ent_meta.GetClass
		local getbyindex = Entity
		local max_players = game.MaxPlayers()

		hook.Add("OnEntityCreated", "ADS_DisableTransmit", function(ent)
			if not valident(ent) then return end
			local class = getclass(ent)

			local rope = class == "keyframe_rope"
			local trail = class == "env_spritetrail"

			if not (rope or trail) then return end

			local p = NULL
			for i = 1, max_players do
				p = getbyindex(i)
				if valident(p) then
					if p:GetInfo"ads_applytomapents" == "0" and ent:CreatedByMap() then continue end
					if rope and p:GetInfo"r_drawropes2" == "0" then transmitstate(ent, p, true) end
					if trail and p:GetInfo"r_drawtrails" == "0" then transmitstate(ent, p, true) end
				end
			end
		end)
	end

	do
		local cvar_net_cd = CreateConVar(
			"ads_net_cooldown",
			"1",
			{ FCVAR_ARCHIVE, FCVAR_NEVER_AS_STRING, FCVAR_SERVER_CANNOT_QUERY },
			"Max cooldown after applys ADS settings on server-side for one client",
			.1,
			300
		)

		local flCurTime = CurTime
		local cvarfloat = FindMetaTable"ConVar".GetFloat
		local readstr = net.ReadString
		local strlen = ('').len
		local getallmatchclass = ents.FindByClass
		local ismapcreated = ent_meta.CreatedByMap
		local getinfocvar = FindMetaTable"Player".GetInfo

		local GetADSNetCooldown = function(p) return p.m_flADSNetCooldown or 0 end
		local SetADSNetCooldown = function(p, v) p.m_flADSNetCooldown = v end

		local cvarlist = {
			["r_drawropes2"] = "keyframe_rope",
			["r_drawtrails"] = "env_spritetrail"
		}

		local function UpdatePlayerTransmitStateForCvar(cvar_type, ply)
			local class = cvarlist[cvar_type]
			if not class then return end

			local t = getallmatchclass(class)
			local len = #t
			local e = NULL

			for i = 1, len do
				e = t[i]
				if getinfocvar(ply, "ads_applytomapents") == "0" and ismapcreated(e) then continue end
				transmitstate(e, ply, getinfocvar(ply, cvar_type) == "0")
			end
		end

		util.AddNetworkString"ads_return_transmit"
		net.Receive("ads_return_transmit", function(l, ply)
			if l < 100 or l > 150 then return end
			if GetADSNetCooldown(ply) > flCurTime() then return end
			local cd = cvarfloat(cvar_net_cd)
			SetADSNetCooldown(ply, flCurTime() + (cd == 0 and 1 or cd))

			local cvar_type = readstr()
			if not cvar_type or strlen(cvar_type) == 0 then return end

			UpdatePlayerTransmitStateForCvar(cvar_type, ply)
		end)

		hook.Add("PlayerInitialSpawn", "ADS_DisableTransmit", function(ply)
			if getinfocvar(ply, "r_drawropes2") ~= "1" then
				UpdatePlayerTransmitStateForCvar("r_drawropes2", ply)
			end

			if getinfocvar(ply, "r_drawtrails") ~= "1" then
				UpdatePlayerTransmitStateForCvar("r_drawtrails", ply)
			end
		end)
	end
else
	CreateClientConVar("ads_applytomapents", "0", true, true, "Allow ADS apply your draw settings to entities created by map") -- too lazy for create callback for this
	CreateClientConVar("r_drawropes2", "1", true, true)
	CreateClientConVar("r_drawtrails", "1", true, true)

	do
		local function cvar_callback(cvar_name, old, new)
			if old == new then return end
			local bNew = tobool(new)
			if tobool(old) == bNew then return end

			net.Start"ads_return_transmit"
				net.WriteString(cvar_name)
			net.SendToServer()
		end
		cvars.AddChangeCallback("r_drawropes2", cvar_callback, "ads_transmit")
		cvars.AddChangeCallback("r_drawtrails", cvar_callback, "ads_transmit")
	end

	do
		local function AdvancedDrawSettings(bar)
			local m = bar:AddOrGetMenu"#menubar.drawing"

			m:AddSpacer()

			m:AddCVar("#menubar.drawing.ads.ropes", "r_drawropes2", "1", "0")
			m:AddCVar("#menubar.drawing.ads.trails", "r_drawtrails", "1", "0")
		end
		hook.Add("PopulateMenuBar", "AdvancedDrawSettings", AdvancedDrawSettings)
	end

	do
		local function AdvancedDrawSettings()
			spawnmenu.AddToolMenuOption("Utilities", "User", "AdvancedDrawSettings", "#spawnmenu.utilities.adw", '', '', function(pnl)
				pnl:AddControl("CheckBox", { Label = "#utilities.ads.mapallow", Command = "ads_applytomapents" })
				pnl:AddControl("CheckBox", { Label = "#menubar.drawing.ads.ropes", Command = "r_drawropes2" })
				pnl:AddControl("CheckBox", { Label = "#menubar.drawing.ads.trails", Command = "r_drawtrails" })
			end)
		end
		hook.Add("PopulateToolMenu", "AdvancedDrawSettings", AdvancedDrawSettings)
	end
end