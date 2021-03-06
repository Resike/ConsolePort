---------------------------------------------------------------
-- CursorRaid.lua: Secure unit targeting cursor for combat
---------------------------------------------------------------
-- Creates a cursor inside the secure environment that is used
-- to iterate over unit frames and select units based on where
-- their respective frame is drawn on screen.
-- Gathers all nodes by recursively scanning UIParent for
-- secure frames with the "unit" attribute assigned.

local addOn, db = ...
local Flash = db.UIFrameFlash
local FadeIn = db.UIFrameFadeIn
local FadeOut = db.UIFrameFadeOut
---------------------------------------------------------------
local UIHandle = CreateFrame("Frame", addOn.."UIHandle", UIParent, "SecureHandlerBaseTemplate, SecureHandlerStateTemplate")
local Cursor = CreateFrame("Frame", addOn.."RaidCursor", UIParent)
---------------------------------------------------------------
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local SetPortraitTexture = SetPortraitTexture
local SetPortraitToTexture = SetPortraitToTexture
---------------------------------------------------------------
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
---------------------------------------------------------------
local UI_SCALE = UIParent:GetScale()
---------------------------------------------------------------
local pi = math.pi
local abs = abs
local GetTime = GetTime
---------------------------------------------------------------
UIParent:HookScript("OnSizeChanged", function(self)
	UI_SCALE = self:GetScale()
	if Cursor and Cursor.Spell then
		Cursor.Spell:Hide()
		Cursor.Spell:Show()
	end
end)
---------------------------------------------------------------
local Key = {
	Up 		= ConsolePort:GetUIControlKey("CP_L_UP"),
	Down 	= ConsolePort:GetUIControlKey("CP_L_DOWN"),
	Left 	= ConsolePort:GetUIControlKey("CP_L_LEFT"),
	Right 	= ConsolePort:GetUIControlKey("CP_L_RIGHT"),
}
---------------------------------------------------------------
UIHandle:Execute(format([[
	ALL = newtable()
	DPAD = newtable()

	Key = newtable()
	Key.Up = %s
	Key.Down = %s
	Key.Left = %s
	Key.Right = %s

	SPELLS = newtable()
	PAGE = 1
	ID = 0

	Units = newtable()
	Actions = newtable()

	Helpful = newtable()
	Harmful = newtable()
]], Key.Up, Key.Down, Key.Left, Key.Right))

-- Raid cursor run snippets
---------------------------------------------------------------
UIHandle:Execute([[
	GetNodes = [=[
		local node = CurrentNode
		local children = newtable(node:GetChildren())
		local unit = node:GetAttribute("unit")
		local action = node:GetAttribute("action")
		local childUnit
		for i, child in pairs(children) do
			childUnit = child:GetAttribute("unit")
			if childUnit == nil or childUnit ~= unit then
				CurrentNode = child
				self:Run(GetNodes)
			end
		end
		if unit and not action and node ~= self then
			local left, bottom, width, height = node:GetRect()
			if left and bottom then
				tinsert(Units, node)
			end
		elseif action and node ~= self then
			local id = action >= 0 and action <= 12 and (PAGE-1) * 12 + action or action >= 0 and action
			if id then
				local actionType, actionID, subType = GetActionInfo(id)
				if actionType == "spell" and subType == "spell" then
					local spellBookID = SPELLS[actionID]
					local helpful = spellBookID and IsHelpfulSpell(spellBookID, subType)
					local harmful = spellBookID and IsHarmfulSpell(spellBookID, subType)
					if helpful then
						tinsert(Helpful, node)
					elseif harmful then
						tinsert(Harmful, node)
					end
				end
			end
		end
	]=]
	SetCurrent = [=[
		if old and old:IsVisible() then
			current = old
		elseif (not current and Units[1]) or (current and Units[1] and not current:IsVisible()) then
			for i, Node in pairs(Units) do
				if Node:IsVisible() then
					current = Node
					break
				end
			end
		end
	]=]
	FindClosestNode = [=[
		if current and key ~= 0 then
			local left, bottom, width, height = current:GetRect()
			local thisY = bottom+height/2
			local thisX = left+width/2
			local nodeY, nodeX = 10000, 10000
			local destY, destX, diffY, diffX, total, swap
			for i, destination in pairs(Units) do
				if destination:IsVisible() then
					left, bottom, width, height = destination:GetRect()
					destY = bottom+height/2
					destX = left+width/2
					diffY = abs(thisY-destY)
					diffX = abs(thisX-destX)
					total = diffX + diffY
					if total < nodeX + nodeY then
						if 	key == Key.Up then
							if 	diffY > diffX and 	-- up/down
								destY > thisY then 	-- up
								swap = true
							end
						elseif key == Key.Down then
							if 	diffY > diffX and 	-- up/down
								destY < thisY then 	-- down
								swap = true
							end
						elseif key == Key.Left then
							if 	diffY < diffX and 	-- left/right
								destX < thisX then 	-- left
								swap = true
							end
						elseif key == Key.Right then
							if 	diffY < diffX and 	-- left/right
								destX > thisX then 	-- right
								swap = true
							end
						end
					end
					if swap then
						nodeX = diffX
						nodeY = diffY
						current = destination
						swap = false
					end
				end
			end
		end
	]=]
	SelectNode = [=[
		key = ...
		if current then
			old = current
		end

		self:Run(SetCurrent)
		self:Run(FindClosestNode)

		for i, action in pairs(Helpful) do
			action:SetAttribute("unit", action:GetAttribute("originalUnit"))
		end

		for i, action in pairs(Harmful) do
			action:SetAttribute("unit", action:GetAttribute("originalUnit"))
		end

		if current then
			local unit = current:GetAttribute("unit")
			Focus:SetAttribute("focus", unit)
			self:ClearAllPoints()
			self:SetPoint("CENTER", current, "CENTER", 0, 0)
			self:SetAttribute("node", current)
			self:SetAttribute("unit", unit)
			self:SetBindingClick(true, "BUTTON2", current, "LeftButton")
			self:SetBindingClick(true, "SHIFT-BUTTON2", current, "RightButton")
			self:SetBindingClick(true, "SHIFT-BUTTON1", Focus, "LeftButton")
			if PlayerCanAttack(unit) then
				self:SetAttribute("relation", "harm")
				for i, action in pairs(Harmful) do
					action:SetAttribute("originalUnit", action:GetAttribute("unit"))
					action:SetAttribute("unit", unit)
				end
			elseif PlayerCanAssist(unit) then
				self:SetAttribute("relation", "help")
				for i, action in pairs(Helpful) do
					action:SetAttribute("originalUnit", action:GetAttribute("unit"))
					action:SetAttribute("unit", unit)
				end
			end
		else
			self:ClearBinding("BUTTON2")
			self:ClearBinding("SHIFT-BUTTON2")
			self:ClearBinding("SHIFT-BUTTON1")
		end
	]=]
	UpdateFrameStack = [=[
		Units = wipe(Units)
		Helpful = wipe(Helpful)
		Harmful = wipe(Harmful)
		for _, Frame in pairs(newtable(self:GetParent():GetChildren())) do
			if Frame:IsProtected() then
				CurrentNode = Frame
				self:Run(GetNodes)
			end
		end
	]=]
	ToggleCursor = [=[
		if IsEnabled then
			for binding, name in pairs(DPAD) do
				local key = GetBindingKey(binding)
				if key then
					self:SetBindingClick(true, key, "ConsolePortRaidCursorButton"..name)
				end
			end
			self:Run(UpdateFrameStack)
			self:Run(SelectNode, 0)
		else
			self:SetAttribute("node", nil)
			self:ClearBindings()

			for i, action in pairs(Helpful) do
				action:SetAttribute("unit", action:GetAttribute("originalUnit"))
			end
			
			for i, action in pairs(Harmful) do
				action:SetAttribute("unit", action:GetAttribute("originalUnit"))
			end
		end
	]=]
	UpdateActionPage = [=[
		PAGE = ...
		if PAGE == "temp" then
			if HasTempShapeshiftActionBar() then
				PAGE = GetTempShapeshiftBarIndex()
			else
				PAGE = 1
			end
		elseif PAGE == "possess" then
			PAGE = self:GetFrameRef("ActionBar"):GetAttribute("actionpage") or 1
			if PAGE <= 10 then
				PAGE = self:GetFrameRef("OverrideBar"):GetAttribute("actionpage") or 12
			end
			if PAGE <= 10 then
				PAGE = 12
			end
		end
		self:Run(UpdateFrameStack)
	]=]
]])
------------------------------------------------------------------------------------------------------------------------------
local ToggleCursor = CreateFrame("Button", addOn.."RaidCursorToggle", UIHandle, "SecureActionButtonTemplate")
ToggleCursor:RegisterForClicks("LeftButtonDown")
UIHandle:WrapScript(ToggleCursor, "OnClick", [[
	local UIHandle = self:GetParent()
	IsEnabled = not IsEnabled
	UIHandle:Run(ToggleCursor)
]])
------------------------------------------------------------------------------------------------------------------------------
local SetFocus = CreateFrame("Button", addOn.."RaidCursorFocus", UIHandle, "SecureActionButtonTemplate")
SetFocus:SetAttribute("type", "focus")
UIHandle:SetFrameRef("SetFocus", SetFocus)
UIHandle:Execute([[ Focus = self:GetFrameRef("SetFocus") ]])
------------------------------------------------------------------------------------------------------------------------------
local buttons = {
	Up 		= {binding = "CP_L_UP", 	key = Key.Up},
	Down 	= {binding = "CP_L_DOWN", 	key = Key.Down},
	Left 	= {binding = "CP_L_LEFT", 	key = Key.Left},
	Right 	= {binding = "CP_L_RIGHT",	key = Key.Right},
}

for name, button in pairs(buttons) do
	local btn = CreateFrame("Button", addOn.."RaidCursorButton"..name, UIHandle, "SecureActionButtonTemplate")
	btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
	btn:SetAttribute("type", "target")
	UIHandle:WrapScript(btn, "OnClick", format([[
		local UIHandle = self:GetParent()
		if down then
			UIHandle:Run(SelectNode, %s)
		end
	]], button.key))
	UIHandle:Execute(format([[
		DPAD.%s = "%s"
	]], button.binding, name))
end
---------------------------------------------------------------
local currentPage, actionpage = ConsolePort:GetActionPageState()
RegisterStateDriver(UIHandle, "actionpage", actionpage)
UIHandle:SetAttribute("_onstate-actionpage", [[ self:Run(UpdateActionPage, newstate) ]])
UIHandle:SetAttribute("actionpage", currentPage)
---------------------------------------------------------------

-- Index the entire spellbook by using spell ID as key and spell book slot as value.
-- IsHarmfulSpell/IsHelpfulSpell functions can use spell book slot, but not actual spell IDs.
local function SecureSpellBookUpdate(self)
	if not InCombatLockdown() then
		if UIHandle then
			for id=1, MAX_SPELLS do
				local ok, err, _, _, _, _, _, spellID = pcall(GetSpellInfo, id, "spell")
				if ok then
					UIHandle:Execute(format([[
						SPELLS[%d] = %d
					]], spellID, id))
				else
					break
				end
			end
		end
		self:RemoveUpdateSnippet(SecureSpellBookUpdate)
	end
end

function ConsolePort:SetupRaidCursor()
	self:AddUpdateSnippet(SecureSpellBookUpdate)

	-- Update the spell table when a new spell is learned.
	UIHandle:SetScript("OnEvent", function(_, event, ...)
		if event == "LEARNED_SPELL_IN_TAB" then
			self:AddUpdateSnippet(SecureSpellBookUpdate)
		end
	end)
	---------------------------------------------------------------

	Cursor.Timer = 0
	Cursor:SetScript("OnUpdate", Cursor.Update)
	Cursor:SetScript("OnEvent", Cursor.Event)

	currentPage = nil
	buttons = nil
	Key = nil

end

---------------------------------------------------------------
Cursor:SetSize(32,32)
Cursor:SetFrameStrata("TOOLTIP")
Cursor:SetPoint("CENTER", 0, 0)
Cursor:SetAlpha(0)
---------------------------------------------------------------
Cursor.BG = Cursor:CreateTexture(nil, "BACKGROUND")
Cursor.BG:SetTexture("Interface\\Cursor\\Item")
Cursor.BG:SetAllPoints(Cursor)
---------------------------------------------------------------
Cursor.UnitPortrait = Cursor:CreateTexture(nil, "ARTWORK", nil, 6)
Cursor.UnitPortrait:SetSize(42, 42)
Cursor.UnitPortrait:SetPoint("TOPLEFT", Cursor, "CENTER", 0, 0)
---------------------------------------------------------------
Cursor.SpellPortrait = Cursor:CreateTexture(nil, "ARTWORK", nil, 7)
Cursor.SpellPortrait:SetSize(42, 42)
Cursor.SpellPortrait:SetPoint("TOPLEFT", Cursor, "CENTER", 0, 0)
---------------------------------------------------------------
Cursor.Border = Cursor:CreateTexture(nil, "OVERLAY", nil, 6)
Cursor.Border:SetSize(54, 54)
Cursor.Border:SetPoint("CENTER", Cursor.UnitPortrait, 0, 0)
Cursor.Border:SetTexture("Interface\\AddOns\\ConsolePort\\Textures\\UtilityBorder")
---------------------------------------------------------------
Cursor.Health = Cursor:CreateTexture(nil, "OVERLAY", nil, 7)
Cursor.Health:SetSize(54, 54)
Cursor.Health:SetPoint("BOTTOM", Cursor.Border, 0, 0)
Cursor.Health:SetTexture("Interface\\AddOns\\ConsolePort\\Textures\\UtilityBorderHighlight")
---------------------------------------------------------------
Cursor.Spell = CreateFrame("PlayerModel", nil, Cursor)
Cursor.Spell:SetAlpha(1)
Cursor.Spell:SetDisplayInfo(42486)
Cursor.Spell:SetScript("OnShow", function(self)
	self:SetSize(110 / UI_SCALE, 110 / UI_SCALE)
	self:SetPoint("CENTER", Cursor, "BOTTOMLEFT", 36, 2 / UI_SCALE)
end)
---------------------------------------------------------------
Cursor.Group = Cursor:CreateAnimationGroup()
---------------------------------------------------------------
Cursor.Scale1 = Cursor.Group:CreateAnimation("Scale")
Cursor.Scale1:SetDuration(0.1)
Cursor.Scale1:SetSmoothing("IN")
Cursor.Scale1:SetOrder(1)
Cursor.Scale1:SetOrigin("CENTER", 0, 0)
---------------------------------------------------------------
Cursor.Scale2 = Cursor.Group:CreateAnimation("Scale")
Cursor.Scale2:SetSmoothing("OUT")
Cursor.Scale2:SetOrder(2)
Cursor.Scale2:SetOrigin("CENTER", 0, 0)
---------------------------------------------------------------
Cursor.CastBar = Cursor:CreateTexture(nil, "OVERLAY")
Cursor.CastBar:SetAlpha(0)
Cursor.CastBar:SetSize(128, 128)
Cursor.CastBar:SetPoint("CENTER", Cursor.UnitPortrait, 0, 0)
Cursor.CastBar:SetTexture("Interface\\AddOns\\ConsolePort\\Textures\\Castbar\\CastBarShadow")
---------------------------------------------------------------
Cursor:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Cursor:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
--Cursor:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
--Cursor:RegisterEvent("UNIT_SPELLCAST_DELAYED")
--Cursor:RegisterEvent("UNIT_SPELLCAST_FAILED")
--Cursor:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
--Cursor:RegisterEvent("UNIT_SPELLCAST_SENT")
Cursor:RegisterEvent("UNIT_SPELLCAST_START")
Cursor:RegisterEvent("UNIT_SPELLCAST_STOP")
Cursor:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
---------------------------------------------------------------
function Cursor:Event(event, ...)
	local unit, spell, _, _, spellID = ...

	if unit ~= "player" then
		return
	end

	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		local name, _, _, texture, startTime, endTime, _, _, _ = UnitChannelInfo("player")

		local targetRelation = UIHandle:GetAttribute("relation")
		local spellRelation = IsHarmfulSpell(name) and "harm" or IsHelpfulSpell(name) and "help"

		if targetRelation == spellRelation then
			local color = self.color
			if color then
				self.CastBar:SetVertexColor(color.r, color.g, color.b)
			end
			self.SpellPortrait:Show()
			self.CastBar:SetRotation(0)
			self.isChanneling = true
			self.spellTexture = texture
			self.startChannel = startTime
			self.endChannel = endTime
			FadeIn(self.CastBar, 0.2, self.CastBar:GetAlpha(), 1)
			FadeIn(self.SpellPortrait, 0.25, self.SpellPortrait:GetAlpha(), 1)
		else
			self.CastBar:Hide()
			self.SpellPortrait:Hide()
		end


	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then self.isChanneling = false
		FadeOut(self.CastBar, 0.2, self.CastBar:GetAlpha(), 0)

	elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then

	elseif event == "UNIT_SPELLCAST_DELAYED" then

	elseif event == "UNIT_SPELLCAST_FAILED" then

	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then

	elseif event == "UNIT_SPELLCAST_SENT" then

	elseif event == "UNIT_SPELLCAST_START" then 
		local name, _, _, texture, startTime, endTime, _, _, _ = UnitCastingInfo("player")

		local targetRelation = UIHandle:GetAttribute("relation")
		local spellRelation = IsHarmfulSpell(name) and "harm" or IsHelpfulSpell(name) and "help"

		if targetRelation == spellRelation then
			local color = self.color
			if color then
				self.CastBar:SetVertexColor(color.r, color.g, color.b)
			end
			self.SpellPortrait:Show()
			self.CastBar:SetRotation(0)
			self.isCasting = true
			self.spellTexture = texture
			self.startCast = startTime
			self.endCast = endTime
			FadeIn(self.CastBar, 0.2, self.CastBar:GetAlpha(), 1)
			FadeIn(self.SpellPortrait, 0.25, self.SpellPortrait:GetAlpha(), 1)
		else
			self.CastBar:Hide()
			self.SpellPortrait:Hide()
		end


	elseif event == "UNIT_SPELLCAST_STOP" then self.isCasting = false
		FadeOut(self.CastBar, 0.2, self.CastBar:GetAlpha(), 0)
		FadeOut(self.SpellPortrait, 0.25, self.SpellPortrait:GetAlpha(), 0)

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local name, _, icon = GetSpellInfo(spell)

		if name and icon then
			local targetRelation = UIHandle:GetAttribute("relation")
			local spellRelation = IsHarmfulSpell(name) and "harm" or IsHelpfulSpell(name) and "help"

			if targetRelation == spellRelation then
				SetPortraitToTexture(self.SpellPortrait, icon)
				if not self.isCasting and not self.isChanneling then 
					Flash(self.SpellPortrait, 0.25, 0.25, 0.75, false, 0.25, 0) 
				else
					self.SpellPortrait:Show()
					FadeOut(self.SpellPortrait, 0.25, self.SpellPortrait:GetAlpha(), 0)
				end
			end
		end
		self.isCasting = false
	end
end

--(frame, fadeInTime, fadeOutTime, flashDuration, showWhenDone, flashInHoldTime, flashOutHoldTime, syncId)

function Cursor:Update(elapsed)
	self.Timer = self.Timer + elapsed
	while self.Timer > 0.1 do
		local node = UIHandle:GetAttribute("node")
		local x, y = UIHandle:GetCenter()
		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		if node then
			local name = node:GetName()
			if ConsolePortCursor:IsVisible() and not InCombatLockdown() then
				self.node = nil
				self:SetAlpha(0)
			elseif name ~= self.node then
				local unit = node:GetAttribute("unit")

				self.unit = unit
				self.node = name
				if self:GetAlpha() == 0 then
					self.Scale1:SetScale(1.5, 1.5)
					self.Scale2:SetScale(1/1.5, 1/1.5)
					self.Scale2:SetDuration(0.5)
					FadeOut(self.Spell, 1, 1, 0.1)
					PlaySound("AchievementMenuOpen")
				else
					self.Scale1:SetScale(1.15, 1.15)
					self.Scale2:SetScale(1/1.15, 1/1.15)
					self.Scale2:SetDuration(0.2)
				end
				self.Group:Stop()
				self.Group:Play()
				self:SetAlpha(1)
			end
		else
			self.node = nil
			self.unit = nil
			self:SetAlpha(0)
		end
		if self.unit then
			if UnitExists(self.unit) then
				local hp = UnitHealth(self.unit)
				local max = UnitHealthMax(self.unit)
				self.color = RAID_CLASS_COLORS[select(2, UnitClass(self.unit))]
				if self.color then
					local red, green, blue = self.color.r, self.color.g, self.color.b
					self.Health:SetVertexColor(red, green, blue)
					self.Spell:SetLight(1, 0, 0, 0, 120, 1, red, green, blue, 100, red, green, blue)
				else
					self.Health:SetVertexColor(0.5, 0.5, 0.5)
					self.Spell:SetLight(1, 0, 0, 0, 120, 1, 1, 1, 1, 100, 1, 1, 1)
				end
				self.Health:SetTexCoord(0, 1, abs(1 - hp / max), 1)
				self.Health:SetHeight(54 * hp / max)
				self.Spell:Show()
				self.Health:Show()
				self.Border:Show()
				self.UnitPortrait:Show()
				self.CastBar:Show()
				SetPortraitTexture(self.UnitPortrait, self.unit)
				if self.isCasting then
					local time = GetTime() * 1000
					local progress = (time - self.startCast) / (self.endCast - self.startCast)
					local resize = 128 - (40 * (1 - progress))
					self.CastBar:SetRotation(-2 * progress * pi)
					self.CastBar:SetSize(resize, resize)
					SetPortraitToTexture(self.SpellPortrait, self.spellTexture)
				elseif self.isChanneling then
					local time = GetTime() * 1000
					local progress = (time - self.startChannel) / (self.endChannel - self.startChannel)
					local resize = 128 - (40 * (1 - progress))
					self.CastBar:SetRotation(-2 * progress * pi)
					self.CastBar:SetSize(resize, resize)
					SetPortraitToTexture(self.SpellPortrait, self.spellTexture)
				else
					SetPortraitTexture(self.UnitPortrait, self.unit)
				end
			else
				self.Health:Hide()
				self.Border:Hide()
				self.UnitPortrait:Hide()
				self.SpellPortrait:Hide()
				self.CastBar:Hide()
			end
		end
		self.Timer = self.Timer - elapsed
	end
end
