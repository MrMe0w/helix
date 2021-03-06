
PLUGIN.name = "Recognition"
PLUGIN.author = "Chessnut"
PLUGIN.description = "Adds the ability to recognize people."

do
	local character = ix.meta.character

	if (SERVER) then
		function character:Recognize(id)
			if (type(id) != "number" and id.GetID) then
				id = id:GetID()
			end

			local recognized = self:GetData("rgn", "")

			if (recognized != "" and recognized:find(","..id..",")) then
				return false;
			end;

			self:SetData("rgn", recognized..","..id..",")

			return true
		end
	end

	function character:DoesRecognize(id)
		if (type(id) != "number" and id.GetID) then
			id = id:GetID()
		end

		return hook.Run("IsCharRecognized", self, id) != false
	end

	function PLUGIN:IsCharRecognized(char, id)
		local other = ix.char.loaded[id]

		if (other) then
			local faction = ix.faction.indices[other:GetFaction()]

			if (faction and faction.isGloballyRecognized) then
				return
			end
		end

		local recognized = char:GetData("rgn", "")

		if (recognized == "") then
			return false
		end

		if (!recognized:find(","..id..",")) then
			return false
		end
	end
end

if (CLIENT) then
	CHAT_RECOGNIZED = CHAT_RECOGNIZED or {}
	CHAT_RECOGNIZED["ic"] = true
	CHAT_RECOGNIZED["y"] = true
	CHAT_RECOGNIZED["w"] = true
	CHAT_RECOGNIZED["me"] = true

	function PLUGIN:IsRecognizedChatType(chatType)
		return CHAT_RECOGNIZED[chatType]
	end

	function PLUGIN:GetDisplayedDescription(client)
		if (client:GetCharacter() and client != LocalPlayer() and LocalPlayer():GetCharacter() and
			!LocalPlayer():GetCharacter():DoesRecognize(client:GetCharacter()) and !hook.Run("IsPlayerRecognized", client)) then
			return L"noRecog"
		end
	end

	function PLUGIN:ShouldAllowScoreboardOverride(client)
		if (ix.config.Get("scoreboardRecognition")) then
			return true
		end
	end

	function PLUGIN:GetDisplayedName(client, chatType)
		if (client != LocalPlayer()) then
			local character = client:GetChar()
			local ourCharacter = LocalPlayer():GetChar()

			if (ourCharacter and character and !ourCharacter:DoesRecognize(character) and !hook.Run("IsPlayerRecognized", client)) then
				if (chatType and hook.Run("IsRecognizedChatType", chatType)) then
					local description = character:GetDescription()

					if (#description > 40) then
						description = description:utf8sub(1, 37).."..."
					end

					return "["..description.."]"
				elseif (!chatType) then
					return L"unknown"
				end
			end
		end
	end

	netstream.Hook("rgnMenu", function()
		local menu = DermaMenu()
			menu:AddOption(L"rgnLookingAt", function()
				netstream.Start("rgn", 1)
			end)
			menu:AddOption(L"rgnWhisper", function()
				netstream.Start("rgn", 2)
			end)
			menu:AddOption(L"rgnTalk", function()
				netstream.Start("rgn", 3)
			end)
			menu:AddOption(L"rgnYell", function()
				netstream.Start("rgn", 4)
			end)
		menu:Open()
		menu:MakePopup()
		menu:Center()
	end)

	netstream.Hook("rgnDone", function()
		hook.Run("OnCharRecognized")
	end)

	function PLUGIN:OnCharRecognized(client, recogCharID)
		surface.PlaySound("buttons/button17.wav")
	end
else
	function PLUGIN:ShowSpare1(client)
		if (client:GetChar()) then
			netstream.Start(client, "rgnMenu")
		end
	end

	netstream.Hook("rgn", function(client, level)
		local targets = {}

		if (level < 2) then
			local entity = client:GetEyeTraceNoCursor().Entity

			if (IsValid(entity) and entity:IsPlayer() and entity:GetChar() and ix.chat.classes.ic:OnCanHear(client, entity)) then
				targets[1] = entity
			end
		else
			local class = "w"

			if (level == 3) then
				class = "ic"
			elseif (level == 4) then
				class = "y"
			end

			class = ix.chat.classes[class]

			for _, v in ipairs(player.GetAll()) do
				if (client != v and v:GetChar() and class:OnCanHear(client, v)) then
					targets[#targets + 1] = v
				end
			end
		end

		if (#targets > 0) then
			local id = client:GetCharacter():GetID()
			local i = 0

			for _, v in ipairs(targets) do
				if (v:GetCharacter():Recognize(id)) then
					i = i + 1
				end
			end

			if (i > 0) then
				netstream.Start(client, "rgnDone")
				hook.Run("OnCharRecognized", client, id)
			end
		end
	end)
end
