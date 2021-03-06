
-- luacheck: globals pac pace

-- This Library is just for PAC3 Integration.
-- You must install PAC3 to make this library works.

PLUGIN.name = "PAC3 Integration"
PLUGIN.author = "Black Tea"
PLUGIN.description = "More Upgraded, More well organized PAC3 Integration made by Black Tea"

if (!pace) then return end

ix.pac = ix.pac or {}
ix.pac.list = ix.pac.list or {}

local meta = FindMetaTable("Player")

-- this stores pac3 part information to plugin's table'
function ix.pac.registerPart(id, outfit)
	ix.pac.list[id] = outfit
end

-- Fixing the PAC3's default stuffs to fit on Helix.
if (CLIENT) then
	-- fixpac command. you can fix the PAC3 errors with this.
	ix.command.Add("FixPAC", {
		description = "@cmdFixPAC",
		OnRun = function(self, client, arguments)
			RunConsoleCommand("pac_restart")
		end
	})

	-- Disable few features of PAC3's feature.
	function PLUGIN:InitializedPlugins()
		-- remove useless PAC3 shits

		hook.Remove("HUDPaint", "pac_InPAC3Editor")
		hook.Remove("InitPostEntity", "pace_autoload_parts")
	end

	-- Remove PAC3 LoadParts
	function pace.LoadParts(name, clear, override_part)
		-- fuck your loading, pay me money bitch
	end

	-- Prohibits players from deleting their own PAC3 outfit.
	concommand.Add("pac_clear_parts", function()
		RunConsoleCommand("pac_restart")
		--STOP BREAKING STUFFS!
	end)

	-- You should be admin to access PAC3 editor.
	function PLUGIN:PrePACEditorOpen()
		local client = LocalPlayer()

		if (!client:IsSuperAdmin()) then
			return false
		end

		return true
	end
else
	-- Reject unauthorized PAC3 submits
	net.Receive("pac_submit", function(_, ply)
		if (!ply) then return end -- ???
		if (!ply:IsSuperAdmin()) then
			ply:NotifyLocalized("illegalAccess")
		return end

		local data = pace.net.DeserializeTable()
		pace.HandleReceivedData(ply, data)
	end)
end

-- Get Player's PAC3 Parts.
function meta:GetParts()
	if (!pac) then return end

	return self:GetNetVar("parts", {})
end

if (SERVER) then
	function meta:AddPart(uid, item)
		if (!pac) then
			ErrorNoHalt("NO PAC3!\n")
		return end

		local curParts = self:GetParts()

		-- wear the parts.
		netstream.Start(player.GetAll(), "partWear", self, uid)
		curParts[uid] = true

		self:SetNetVar("parts", curParts)
	end

	function meta:RemovePart(uid)
		if (!pac) then return end

		local curParts = self:GetParts()

		-- remove the parts.
		netstream.Start(player.GetAll(), "partRemove", self, uid)
		curParts[uid] = nil

		self:SetNetVar("parts", curParts)
	end

	function meta:ResetParts()
		if (!pac) then return end

		netstream.Start(player.GetAll(), "partReset", self, self:GetParts())
		self:SetNetVar("parts", {})
	end

	function PLUGIN:PlayerLoadedChar(client, curChar, prevChar)
		-- If player is changing the char and the character ID is differs from the current char ID.
		if (prevChar and curChar:GetID() != prevChar:GetID()) then
			client:ResetParts()
		end

		-- After resetting all PAC3 outfits, wear all equipped PAC3 outfits.
		if (curChar) then
			local inv = curChar:GetInventory()

			for _, v in pairs(inv:GetItems()) do
				if (v:GetData("equip") == true and v.pacData) then
					client:AddPart(v.uniqueID, v)
				end
			end
		end
	end

	function PLUGIN:PlayerInitialSpawn(client)
		netstream.Start(client, "updatePAC")
	end

	function PLUGIN:PlayerSwitchWeapon(client, oldWeapon, newWeapon)
		local oldItem = IsValid(oldWeapon) and oldWeapon.ixItem
		local newItem = IsValid(newWeapon) and newWeapon.ixItem

		if (oldItem and oldItem.isWeapon and oldItem:GetData("equip") and oldItem.pacData) then
			oldItem:WearPAC(client)
		end

		if (newItem and newItem.isWeapon and newItem.pacData) then
			newItem:RemovePAC(client)
		end
	end
else
	netstream.Hook("updatePAC", function()
		if (!pac) then return end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character) then
				local parts = LocalPlayer():GetParts()

				for k, _ in pairs(parts) do
					if (ix.pac.list[k]) then
						v:AttachPACPart(ix.pac.list[k])
					end
				end
			end
		end
	end)

	netstream.Hook("partWear", function(wearer, uid)
		if (!pac) then return end

		if (!wearer.pac_owner) then
			pac.SetupENT(wearer)
		end

		local itemTable = ix.item.list[uid]
		local newPac = ix.pac.list[uid]

		if (ix.pac.list[uid]) then
			if (itemTable and itemTable.pacAdjust) then
				newPac = table.Copy(ix.pac.list[uid])
				newPac = itemTable:pacAdjust(newPac, wearer)
			end

			if (wearer.AttachPACPart) then
				wearer:AttachPACPart(newPac)
			else
				pac.SetupENT(wearer)

				timer.Simple(0.1, function()
					if (IsValid(wearer) and wearer.AttachPACPart) then
						wearer:AttachPACPart(newPac)
					else
						print("alright, no more PAC3 for you. Go away.")
					end
				end)
			end
		end
	end)

	netstream.Hook("partRemove", function(wearer, uid)
		if (!pac) then return end

		if (!wearer.pac_owner) then
			pac.SetupENT(wearer)
		end

		if (ix.pac.list[uid]) then
			if (wearer.RemovePACPart) then
				wearer:RemovePACPart(ix.pac.list[uid])
			else
				pac.SetupENT(wearer)
			end
		end
	end)

	netstream.Hook("partReset", function(wearer, uidList)
		for k, _ in pairs(uidList) do
			wearer:RemovePACPart(ix.pac.list[k])
		end
	end)

	function PLUGIN:DrawPlayerRagdoll(entity)
		local ply = entity.objCache

		if (IsValid(ply)) then
			if (!entity.overridePAC3) then
				if ply.pac_parts then
					for _, part in pairs(ply.pac_parts) do
						if part.last_owner and part.last_owner:IsValid() then
							hook.Run("OnPAC3PartTransfered", part)
							part:SetOwner(entity)
							part.last_owner = entity
						end
					end
				end
				ply.pac_playerspawn = pac.RealTime -- used for events

				entity.overridePAC3 = true
			end
		end
	end

	function PLUGIN:OnEntityCreated(entity)
		local class = entity:GetClass()

		-- For safe progress, I skip one frame.
		timer.Simple(0.01, function()
			if (class == "prop_ragdoll") then
				if (entity:GetNetVar("player")) then
					entity.RenderOverride = function()
						entity.objCache = entity:GetNetVar("player")
						entity:DrawModel()

						hook.Run("DrawPlayerRagdoll", entity)
					end
				end
			end

			if (class:find("HL2MPRagdoll")) then
				for _, v in ipairs(player.GetAll()) do
					if (v:GetRagdollEntity() == entity) then
						entity.objCache = v
					end
				end

				entity.RenderOverride = function()
					entity:DrawModel()

					hook.Run("DrawPlayerRagdoll", entity)
				end
			end
		end)
	end

	function PLUGIN:OnCharInfoSetup(infoPanel)
		if (pac and infoPanel.model) then
			-- Get the F1 ModelPanel.
			local mdl = infoPanel.model
			local ent = mdl.Entity

			-- If the ModelPanel's Entity is valid, setup PAC3 Function Table.
			if (ent and IsValid(ent)) then
				-- Setup function table.
				pac.SetupENT(ent)

				local parts = LocalPlayer():GetParts()

				-- Wear current player's PAC3 Outfits on the ModelPanel's Clientside Model Entity.
				for k, _ in pairs(parts) do
					if (ix.pac.list[k]) then
						ent:AttachPACPart(ix.pac.list[k])
					end
				end

				-- Overrride Model Drawing function of ModelPanel. (Function revision: 2015/01/05)
				-- by setting ent.forcedraw true, The PAC3 outfit will drawn on the model even if it's NoDraw Status is true.
				ent.forceDraw = true
			end
		end
	end

	function PLUGIN:DrawHelixModelView(panel, ent)
		if (LocalPlayer():GetChar()) then
			if (pac) then
				pac.RenderOverride(ent, "opaque")
				pac.RenderOverride(ent, "translucent", true)
			end
		end
	end
end

function PLUGIN:InitializedPlugins()
	local items = ix.item.list

	for _, v in pairs(items) do
		if (v.pacData) then
			ix.pac.list[v.uniqueID] = v.pacData
		end
	end
end
