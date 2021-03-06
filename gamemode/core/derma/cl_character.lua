
local PANEL = {}
local gradient = surface.GetTextureID("vgui/gradient-u")
local gradient2 = surface.GetTextureID("vgui/gradient-d")

function PANEL:Init()
	local fadeSpeed = 1

	if (IsValid(ix.gui.loading)) then
		ix.gui.loading:Remove()
	end

	if (ix.config.Get("intro", true) and !ix.localData.intro) then
		timer.Simple(0.1, function()
			vgui.Create("ixIntro", self)
		end)
	else
		self:PlayMusic()
	end

	if (IsValid(ix.gui.char) or (LocalPlayer().GetChar and LocalPlayer():GetChar())) then
		ix.gui.char:Remove()
		fadeSpeed = 0
	end

	ix.gui.char = self

	self:Dock(FILL)
	self:MakePopup()
	self:Center()
	self:ParentToHUD()

	self.darkness = self:Add("DPanel")
	self.darkness:Dock(FILL)
	self.darkness.Paint = function(this, w, h)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawRect(0, 0, w, h)
	end
	self.darkness:SetZPos(99)

	self.title = self:Add("DLabel")
	self.title:SetContentAlignment(5)
	self.title:SetPos(0, 64)
	self.title:SetSize(ScrW(), 64)
	self.title:SetFont("ixTitleFont")
	self.title:SetText(L2("schemaName") or Schema.name or L"unknown")
	self.title:SizeToContentsY()
	self.title:SetTextColor(color_white)
	self.title:SetZPos(100)
	self.title:SetAlpha(0)
	self.title:AlphaTo(255, fadeSpeed, 3 * fadeSpeed, function()
		self.darkness:AlphaTo(0, 2 * fadeSpeed, 0, function()
			self.darkness:SetZPos(-99)
		end)
	end)
	self.title:SetExpensiveShadow(2, Color(0, 0, 0, 200))

	self.subTitle = self:Add("DLabel")
	self.subTitle:SetContentAlignment(5)
	self.subTitle:MoveBelow(self.title, 0)
	self.subTitle:SetSize(ScrW(), 64)
	self.subTitle:SetFont("ixSubTitleFont")
	self.subTitle:SetText(L2("schemaDesc") or Schema.description or L"noDesc")
	self.subTitle:SizeToContentsY()
	self.subTitle:SetTextColor(color_white)
	self.subTitle:SetAlpha(0)
	self.subTitle:AlphaTo(255, 4 * fadeSpeed, 3 * fadeSpeed)
	self.subTitle:SetExpensiveShadow(2, Color(0, 0, 0, 200))

	self.icon = self:Add("DHTML")
	self.icon:SetPos(ScrW() - 96, 8)
	self.icon:SetSize(86, 86)
	self.icon:SetHTML(string.format([[
		<html>
			<body style="margin: 0; padding: 0; overflow: hidden;">
				<img src="%s" width="86" height="86" />
			</body>
		</html>
	]], ix.config.Get("logo", "https://static.miraheze.org/nutscriptwiki/2/26/Nutscript.png")))
	self.icon:SetTooltip(ix.config.Get("logoURL", "https://nutscript.net"))

	self.icon.click = self.icon:Add("DButton")
	self.icon.click:Dock(FILL)
	self.icon.click.DoClick = function(this)
		gui.OpenURL(ix.config.Get("logoURL", "https://nutscript.net"))
	end
	self.icon.click:SetAlpha(0)
	self.icon:SetAlpha(150)

	local x, y = ScrW() * 0.1, ScrH() * 0.3
	local i = 1

	self.buttons = {}
	surface.SetFont("ixMenuButtonFont")

	local function AddMenuLabel(text, callback, isLast, noTranslation, parent)
		parent = parent or self

		local label = parent:Add("ixMenuButton")
		label:SetPos(x, y)
		label:SetText(text, noTranslation)
		label:SetContentAlignment(4)
		label:SetAlpha(0)
		label:AlphaTo(255, 0.3, (fadeSpeed * 6) + 0.15 * i, function()
			if (isLast) then
				fadeSpeed = 0
			end
		end)

		if (callback) then
			label.DoClick = function(this)
				if (this:GetAlpha() == 255 and callback) then
					callback(this)
				end
			end
		end

		i = i + 0.33
		y = y + label:GetTall() + 16

		self.buttons[#self.buttons + 1] = label
		return label
	end

	local function ClearAllButtons(callback)
		x, y = ScrW() * 0.1, ScrH() * 0.3

		local buttonIndex = 1
		local max = table.Count(self.buttons)

		for _, v in pairs(self.buttons) do
			local reachedMax = buttonIndex == max

			v:AlphaTo(0, 0.3, 0.15 * buttonIndex, function()
				if (reachedMax and callback) then
					callback()
				end

				v.noClick = true
				v:Remove()
			end)

			buttonIndex = buttonIndex + 1
		end

		self.buttons = {}
	end

	self.fadePanels = {}

	local CreateMainButtons

	local function CreateReturnButton()
		AddMenuLabel("return", function()
			if (IsValid(self.creation) and self.creation.creating) then
				return
			end

			self.setupCharList = nil

			for _, v in pairs(self.fadePanels) do
				if (IsValid(v)) then
					v:AlphaTo(0, 0.25, 0, function()
						v:Remove()
					end)
				end
			end

			self.fadePanels = {}
			ClearAllButtons(CreateMainButtons)
		end)
	end

	function CreateMainButtons()
		local count = 0

		for _, v in pairs(ix.faction.teams) do
			if (ix.faction.HasWhitelist(v.index)) then
				count = count + 1
			end
		end

		local maxChars = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxChars", 5)
		if (count > 0 and #ix.characters < maxChars and hook.Run("ShouldMenuButtonShow", "create") != false) then
			AddMenuLabel("create", function()
				ClearAllButtons(function()
					CreateReturnButton()

					local fadedIn = false

					for _, v in SortedPairs(ix.faction.teams) do
						if (ix.faction.HasWhitelist(v.index)) then
							AddMenuLabel(L(v.name), function()
								if (!self.creation or self.creation.faction != v.index) then
									self.creation = self:Add("ixCharCreate")
									self.creation:SetAlpha(fadedIn and 255 or 0)
									self.creation:SetUp(v.index)
									self.creation:AlphaTo(255, 0.5, 0)
									self.fadePanels[#self.fadePanels + 1] = self.creation

									self.finish = self:Add("ixMenuButton")
									self.finish:SetPos(ScrW() * 0.3 - 32, ScrH() * 0.3 + 16)
									self.finish:SetText("finish")
									self.finish:MoveBelow(self.creation, 4)
									self.finish.DoClick = function(this)
										if (!self.creation.creating) then
											local payload = {}

											for varKey, var in SortedPairsByMemberValue(ix.char.vars, "index") do
												local value = self.creation.payload[varKey]

												if (!var.bNoDisplay or var.OnValidate) then
													if (var.OnValidate) then
														local result = {var.OnValidate(value, self.creation.payload, LocalPlayer())}

														if (result[1] == false) then
															self.creation.notice:SetType(1)
															self.creation.notice:SetText(L(unpack(result, 2)).."!")

															return
														end
													end

													payload[varKey] = value
												end
											end

											self.creation.notice:SetType(6)
											self.creation.notice:SetText(L"creating")
											self.creation.creating = true
											self.finish:AlphaTo(0, 0.5, 0)

											netstream.Hook("charAuthed", function(fault, ...)
												timer.Remove("ixCharTimeout")

												if (type(fault) == "string") then
													self.creation.notice:SetType(1)
													self.creation.notice:SetText(L(fault, ...))
													self.creation.creating = nil
													self.finish:AlphaTo(255, 0.5, 0)

													return
												end

												if (type(fault) == "table") then
													ix.characters = fault
												end

												for _, panel in pairs(self.fadePanels) do
													if (IsValid(panel)) then
														panel:AlphaTo(0, 0.25, 0, function()
															panel:Remove()
														end)
													end
												end

												self.fadePanels = {}
												ClearAllButtons(CreateMainButtons)
											end)

											timer.Create("ixCharTimeout", 20, 1, function()
												if (IsValid(self.creation) and self.creation.creating) then
													self.creation.notice:SetType(1)
													self.creation.notice:SetText(L"unknownError")
													self.creation.creating = nil
													self.finish:AlphaTo(255, 0.5, 0)
												end
											end)

											netstream.Start("charCreate", payload)
										end
									end

									self.fadePanels[#self.fadePanels + 1] = self.finish

									fadedIn = true
								end
							end)
						end
					end
				end)
			end)
		end

		if (#ix.characters > 0 and hook.Run("ShouldMenuButtonShow", "load") != false) then
			AddMenuLabel("load", function()
				ClearAllButtons(function()
					CreateReturnButton()

					local lastButton
					local id
					local width = 128

					self.charList = self:Add("DScrollPanel")
					self.charList:SetPos(x, y)
					self.charList:SetTall(ScrH() * 0.5)
					self.charList:SetAlpha(0)

					self.fadePanels[#self.fadePanels + 1] = self.charList

					self.model = self:Add("ixModelPanel")
					self.model:SetPos(ScrW() * 0.35, ScrH() * 0.2 + 16)
					self.model:MoveBelow(self.subTitle, 64)
					self.model:SetSize(ScrW() * 0.3, ScrH() * 0.7)
					self.model:SetModel("models/error.mdl")
					self.model:SetFOV(49)
					self.model:SetAlpha(0)
					self.model:AlphaTo(255, 0.5, 0)
					self.model.PaintModel = self.model.Paint
					self.model.Paint = function(this, w, h)
						local color = self.model.teamColor or color_black

						surface.SetDrawColor(color.r, color.g, color.b, 125)
						surface.SetTexture(gradient2)
						surface.DrawTexturedRect(0, 0, w, h)

						this:PaintModel(w, h)
					end
					self.fadePanels[#self.fadePanels + 1] = self.model

					self.choose = self.model:Add("ixMenuButton")
					self.choose:SetWide(self.model:GetWide() * 0.45)
					self.choose:SetText("choose")
					self.choose:Dock(LEFT)
					self.choose.DoClick = function()
						if ((self.nextUse or 0) < CurTime()) then
							self.nextUse = CurTime() + 1
						else
							return
						end

						local status, result = hook.Run("CanPlayerUseChar", LocalPlayer(), ix.char.loaded[id])

						if (status == false) then
							if (result:sub(1, 1) == "@") then
								ix.util.NotifyLocalized(result:sub(2))
							else
								ix.util.Notify(result)
							end

							return
						end

						if (!self.choosing and id) then
							self.choosing = true
							self.darkness:SetZPos(999)
							self.darkness:AlphaTo(255, 1, 0, function()
								self:Remove()

								local darkness = vgui.Create("DPanel")
								darkness:SetZPos(999)
								darkness:SetSize(ScrW(), ScrH())
								darkness.Paint = function(this, w, h)
									surface.SetDrawColor(0, 0, 0)
									surface.DrawRect(0, 0, w, h)
								end

								hook.Add("CharacterLoaded", "ix.gui.char:CharacterLoaded", function(character)
									if (IsValid(darkness)) then
										darkness:AlphaTo(0, 5, 0.5, function()
											darkness:Remove()

											hook.Remove("CharacterLoaded", "ix.gui.char:CharacterLoaded")
										end)
									end
								end)

								netstream.Start("charChoose", id)
							end)
						end
					end

					self.delete = self.model:Add("ixMenuButton")
					self.delete:SetWide(self.model:GetWide() * 0.45)
					self.delete:SetText("delete")
					self.delete:Dock(RIGHT)
					self.delete.DoClick = function()
						local menu = DermaMenu()
							local confirm = menu:AddSubMenu(L("delConfirm", ix.char.loaded[id]:GetName()))
							confirm:AddOption(L"no"):SetImage("icon16/cross.png")
							confirm:AddOption(L"yes", function()
								netstream.Start("charDel", id)
							end):SetImage("icon16/tick.png")
						menu:Open()
					end

					self.characters = {}

					local function SetupCharacter(character)
						if (id != character:GetID()) then
							self.model:SetModel(character:GetModel())
							self.model.teamColor = team.GetColor(character:GetFaction())

							if (IsValid(self.model.Entity)) then
								self.model.Entity:SetSkin(character:GetData("skin", 0))

								local groups = character:GetData("groups", {})

								for k, v in pairs(groups) do
									self.model.Entity:SetBodygroup(k, v)
								end
							end

							id = character:GetID()
						end
					end

					local function SetupCharList()
						local first = true

						self.charList:Clear()
						self.charList:AlphaTo(255, 0.5, 0.5)

						for _, v in ipairs(ix.characters) do
							local character = ix.char.loaded[v]

							if (character) then
								local label = self.charList:Add("ixMenuButton")
								label:SetText(character:GetName(), true)
								label:Dock(TOP)
								label:SetContentAlignment(4)
								label:DockMargin(0, 0, 0, 4)
								label.DoClick = function(this)
									if (IsValid(lastButton)) then
										lastButton.color = nil
										lastButton:SetTextColor(color_white)
									end

									lastButton = this
									this.color = ix.config.Get("color")
									SetupCharacter(character)
								end

								if (first) then
									SetupCharacter(character)
									label.color = ix.config.Get("color")
									lastButton = label
									first = nil
								end

								if (label:GetWide() > width) then
									width = label:GetWide() + 8
									self.charList:SetWide(width)
								end

								self.characters[#self.characters + 1] = {label = label, id = character:GetID()}
							end
						end
					end

					SetupCharList()

					self.SetupCharList = function(this)
						if (#ix.characters == 0) then
							if (IsValid(self.creation) and self.creation.creating) then
								return
							end

							this.setupCharList = nil

							for _, v in pairs(self.fadePanels) do
								if (IsValid(v)) then
									v:AlphaTo(0, 0.25, 0, function()
										v:Remove()
									end)
								end
							end

							self.fadePanels = {}
							ClearAllButtons(CreateMainButtons)

							return
						end

						SetupCharList()
					end
				end)
			end)
		end

		local hasCharacter = LocalPlayer().GetChar and LocalPlayer():GetChar()

		if (hook.Run("ShouldMenuButtonShow", "leave") != false) then
			AddMenuLabel(hasCharacter and "return" or "leave", function()
				if (!hasCharacter) then
					if (self.darkness:GetAlpha() == 0) then
						self.title:SetZPos(-99)
						self.darkness:SetZPos(99)
						self.darkness:AlphaTo(255, 1.25, 0, function()
							timer.Simple(0.5, function()
								RunConsoleCommand("disconnect")
							end)
						end)
					end
				else
					self:AlphaTo(0, 0.5, 0, function()
						self:Remove()
					end)
				end
			end, true)
		end
	end

	CreateMainButtons()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_TAB and LocalPlayer():GetChar() and !self.choosing) then
		self:Remove()
	end
end

function PANEL:PlayMusic()
	if (ix.menuMusic) then
		ix.menuMusic:Stop()
		ix.menuMusic = nil
	end

	timer.Remove("ixMusicFader")

	local source = ix.config.Get("music", ""):lower()

	if (source:find("%S")) then
		local function callback(music, errorID, fault)
			if (music) then
				music:SetVolume(0.5)

				ix.menuMusic = music
				ix.menuMusic:Play()
			else
				MsgC(Color(255, 50, 50), errorID.." ")
				MsgC(color_white, fault.."\n")
			end
		end

		if (source:find("http")) then
			sound.PlayURL(source, "noplay", callback)
		else
			sound.PlayFile("sound/"..source, "noplay", callback)
		end
	end

	for _, v in ipairs(engine.GetAddons()) do
		if (v.wsid == "1267236756" and v.mounted) then
			return
		end
	end

	Derma_Query(L"contentWarning", L"contentTitle", L"yes", function()
		gui.OpenURL("http://steamcommunity.com/sharedfiles/filedetails/?id=1267236756")
	end, L"no")
end

function PANEL:OnRemove()
	if (ix.menuMusic) then
		local fraction = 1
		local start, finish = RealTime(), RealTime() + 10

		timer.Create("ixMusicFader", 0.1, 0, function()
			if (ix.menuMusic) then
				fraction = 1 - math.TimeFraction(start, finish, RealTime())
				ix.menuMusic:SetVolume(fraction * 0.5)

				if (fraction <= 0) then
					ix.menuMusic:Stop()
					ix.menuMusic = nil

					timer.Remove("ixMusicFader")
				end
			else
				timer.Remove("ixMusicFader")
			end
		end)
	end
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(0, 0, 0, 235)
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, w, h)
end
vgui.Register("ixCharMenu", PANEL, "EditablePanel")

hook.Add("CreateMenuButtons", "ixCharButton", function(tabs)
	tabs["Characters"] = function(panel)
		ix.gui.menu:Remove()
		vgui.Create("ixCharMenu")
	end
end)
