---------------------------------------------------------------
-- General.lua: Base config, reset buttons, triggers, cvars
---------------------------------------------------------------
-- Creates the base config panel and account-wide cvar options.

local addOn, db = ...
local TUTORIAL = db.TUTORIAL
local TEXTURE  = db.TEXTURE
local FadeIn, FadeOut = db.UIFrameFadeIn, db.UIFrameFadeOut
local Settings
---------------------------------------------------------------
-- Config: Account-wide addon CVars.
---------------------------------------------------------------
local function GetAddonSettings()
	return {		
		{	cvar = "autoInteract",
			desc = TUTORIAL.CONFIG.CLICKTOMOVE,
			toggle = Settings.autoInteract,
		},
		{	cvar = "turnCharacter",
			desc = TUTORIAL.CONFIG.TURNMOVE,
			toggle = Settings.turnCharacter,
			needReload = true, 
		},
		{
			cvar = "preventMouseDrift",
			desc = TUTORIAL.CONFIG.MOUSEDRIFTING,
			toggle = Settings.preventMouseDrift,
		},
		{
			cvar = "doubleModTap",
			desc = gsub(format(TUTORIAL.CONFIG.DOUBLEMODTAP, TEXTURE[Settings.shift], TEXTURE[Settings.ctrl]), "Icons64x64", "Icons32x32"),
			toggle = Settings.doubleModTap,
		},
		{	cvar = "disableSmartMouse",
			desc = TUTORIAL.CONFIG.DISABLEMOUSE,
			toggle = Settings.disableSmartMouse,
		},
		{	cvar = "autoExtra",
			desc = TUTORIAL.CONFIG.AUTOEXTRA,
			toggle = Settings.autoExtra,
		},
		{
			cvar = "cameraDistanceMoveSpeed",
			desc = TUTORIAL.CONFIG.FASTCAM,
			toggle = Settings.cameraDistanceMoveSpeed,
		},
		{
			cvar = "autoLootDefault",
			desc = TUTORIAL.CONFIG.AUTOLOOT,
			toggle = Settings.autoLootDefault,
		},
		-- Mouse "events" to the user, but cvars internally
		{
			mouse = true,
			cvar = "mouseOnJump",
			desc = TUTORIAL.MOUSE.JUMPING,
			toggle = Settings.mouseOnJump,
		},
		{
			mouse = true,
			cvar = "mouseOnCenter",
			desc = TUTORIAL.MOUSE.CENTERCURSOR,
			toggle = Settings.mouseOnCenter,
		},
	}
end
---------------------------------------------------------------
-- Mouse: Returns events for mouselook
---------------------------------------------------------------
local function GetMouseSettings()
	return {
		{ 	event 	= {"PLAYER_STARTED_MOVING"},
			desc 	= TUTORIAL.MOUSE.STARTED_MOVING,
			toggle 	= db.Mouse.Events["PLAYER_STARTED_MOVING"]
		},
		{ 	event	= {"PLAYER_TARGET_CHANGED"},
			desc 	= TUTORIAL.MOUSE.TARGET_CHANGED,
			toggle 	= db.Mouse.Events["PLAYER_TARGET_CHANGED"]
		},
		{	event 	= {"CURRENT_SPELL_CAST_CHANGED"},
			desc 	= TUTORIAL.MOUSE.DIRECT_SPELL_CAST,
			toggle 	= db.Mouse.Events["CURRENT_SPELL_CAST_CHANGED"]
		},
		{	event 	= {	"GOSSIP_SHOW", "GOSSIP_CLOSED",
						"MERCHANT_SHOW", "MERCHANT_CLOSED",
						"TAXIMAP_OPENED", "TAXIMAP_CLOSED",
						"QUEST_GREETING", "QUEST_DETAIL",
						"QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
						"SHIPMENT_CRAFTER_OPENED", "SHIPMENT_CRAFTER_CLOSED"},
			desc 	= TUTORIAL.MOUSE.NPC_INTERACTION,
			toggle 	= db.Mouse.Events["GOSSIP_SHOW"]
		},
		{ 	event	= {"QUEST_AUTOCOMPLETE"},
			desc 	= TUTORIAL.MOUSE.QUEST_AUTOCOMPLETE,
			toggle 	= db.Mouse.Events["QUEST_AUTOCOMPLETE"]
		},
		{	event	= {"LOOT_OPENED", "LOOT_CLOSED"},
			desc 	= TUTORIAL.MOUSE.LOOTING,
			toggle 	= db.Mouse.Events["LOOT_OPENED"]
		}
	}
end

---------------------------------------------------------------
-- Config/Mouse: Save general addon CVars.
---------------------------------------------------------------
local function SaveGeneralConfig(self)
	local needReload
	for i, Check in pairs(self.General) do
		local old = Settings[Check.Cvar]
		Settings[Check.Cvar] = Check:GetChecked()
		if Check.Reload and Check:GetChecked() ~= old then
			needReload = true
		end
	end
	for i, Check in pairs(self.Triggers) do
		if Check.Value and Check.Value ~= Settings[Check.Cvar] then
			Settings[Check.Cvar] = Check.Value
			needReload = true
		end
	end

	ConsolePort:UpdateCVars()
	ConsolePort:UpdateSmartMouse()

	for i, Check in pairs(self.Events) do
		for i, Event in pairs(Check.Events) do
			db.Mouse.Events[Event] = Check:GetChecked()
		end
	end

	if self.InteractModule.Enable:GetChecked() and self.InteractModule.BindCatcher.CurrentButton then
		Settings.interactWith = self.InteractModule.BindCatcher.CurrentButton
		Settings.mouseOverMode = self.InteractModule.MouseOver:GetChecked()
	else
		Settings.interactWith = false
		Settings.mouseOverMode = false
	end

	local actionBarStyle = self.ActionBarModule:GetID()
	if not Settings.actionBarStyle or Settings.actionBarStyle ~= actionBarStyle then
		Settings.actionBarStyle = actionBarStyle
		needReload = true
	end

	ConsolePortSettings = db.Settings
	ConsolePortMouse = db.Mouse

	db.Mouse.Cursor.Left = self.LeftClick.button
	db.Mouse.Cursor.Right = self.RightClick.button
	db.Mouse.Cursor.Scroll = self.ScrollClick.button
	
	ConsolePort:LoadEvents()
	ConsolePort:SetupCursor()
	ConsolePort:LoadControllerTheme()
	ConsolePort:UpdateStateDriver()
	ConsolePort:SetupUtilityBelt()
	return needReload
end

---------------------------------------------------------------
-- Config: Reset buttons
---------------------------------------------------------------
local function ResetControllerOnClick(self)
	self:GetParent():GetParent():Hide()
	ConsolePort:CreateSplashFrame()
end

local function ResetBindingsOnClick(self)
	if not InCombatLockdown() then
		self:GetParent():GetParent():Hide()
		local bindings = ConsolePort:GetBindingNames()
		for i, binding in pairs(bindings) do
			local key1, key2 = GetBindingKey(binding)
			if key1 then SetBinding(key1) end
			if key2 then SetBinding(key2) end
		end
		SaveBindings(GetCurrentBindingSet())
		ConsolePort:CreateBindingWizard()
	end
end

local function ResetAllOnClick(self)
	self:SetText(TUTORIAL.CONFIG.CONFIRMRESET)
	self:SetScript("OnClick", function(self)
		SlashCmdList["CONSOLEPORT"]("resetall")
	end)
end

---------------------------------------------------------------
-- Binds: Bind catcher
---------------------------------------------------------------
local function BindCatcherOnKey(self, key)
	local action = key and GetBindingAction(key) and _G[GetBindingAction(key).."_BINDING"]
	FadeIn(ConsolePortCursor, 0.2, ConsolePortCursor:GetAlpha(), 1)
	self:SetScript("OnKeyUp", nil)
	self:EnableKeyboard(false)
	if action then
		self.CurrentButton = action.name
		self:SetText(format(TUTORIAL.CONFIG.INTERACTASSIGNED, db.TEXTURE[self.CurrentButton]))
	elseif key then
		self:SetText(TUTORIAL.CONFIG.INTERACTCATCHER)
	end
end

local function BindCatcherOnClick(self)
	self:EnableKeyboard(true)
	self:SetScript("OnKeyUp", BindCatcherOnKey)
	FadeOut(ConsolePortCursor, 0.2, ConsolePortCursor:GetAlpha(), 0)
	self:SetText(TUTORIAL.BIND.CATCHER)
end

local function BindCatcherOnHide(self)
	BindCatcherOnKey(self)
	FadeOut(self, 0.2, self:GetAlpha(), 0)
end

local function BindCatcherOnShow(self)
	self.CurrentButton = Settings.interactWith
	if self.CurrentButton then
		self:SetText(format(TUTORIAL.CONFIG.INTERACTASSIGNED, db.TEXTURE[self.CurrentButton]))
	else
		self:SetText(TUTORIAL.CONFIG.INTERACTCATCHER)
	end
	FadeIn(self, 0.2, self:GetAlpha(), 1)
end

local function InteractModuleOnShow(self)
	if self.Enable:GetChecked() then
		FadeOut(self.Hand, 0.5, 1, 0.1)
		FadeOut(self.Dude, 0.5, 1, 0.1)
		self.MouseOver:Show()
		self.BindWrapper:Show()
	else
		self.MouseOver:Hide()
		self.BindWrapper:Hide()
		FadeIn(self.Hand, 0.5, 0.1, 1)
		FadeIn(self.Dude, 0.5, 0.1, 1)
	end
end


---------------------------------------------------------------
-- Config: Create panel and children 
---------------------------------------------------------------
tinsert(db.PANELS, {"Config", "General", false, SaveGeneralConfig, false, false, function(self, Config)

	Settings = db.Settings

	local function CreateButton(name, text, OnClick, point)
		local button = db.Atlas.GetFutureButton("$parent"..name, Config)
		button:SetPoint(unpack(point))
		button:SetText(text)
		button:SetScript("OnClick", OnClick)
		return button
	end

	Config.ResetController = CreateButton("ResetController", TUTORIAL.CONFIG.CONTROLLER, ResetControllerOnClick, {"RIGHT", -40, -64})
	Config.ResetBindings = CreateButton("ResetBindings", TUTORIAL.CONFIG.BINDRESET, ResetBindingsOnClick, {"TOP", Config.ResetController, "BOTTOM", 0, -2})
	Config.ResetAll = CreateButton("ResetAll", TUTORIAL.CONFIG.FULLRESET, ResetAllOnClick, {"TOP", Config.ResetBindings, "BOTTOM", 0, -2})
	Config.ShowSlash = CreateButton("ShowSlash", TUTORIAL.CONFIG.SHOWSLASH, SlashCmdList["CONSOLEPORT"], {"TOP", Config.ResetAll, "BOTTOM", 0, -2})

	------------------------------------------------------------------------------------------------------------------------------

	Config.InteractModule = CreateFrame("Frame", nil, Config)
	Config.InteractModule:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.InteractModule:SetPoint("TOPRIGHT", -302, -8)
	Config.InteractModule:SetSize(300, 300)
	Config.InteractModule:SetScript("OnShow", InteractModuleOnShow)

	Config.MouseModule = CreateFrame("Frame", nil, Config)
	Config.MouseModule:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.MouseModule:SetPoint("TOPRIGHT", -8, -8)
	Config.MouseModule:SetSize(300, 300)

	Config.GeneralModule = CreateFrame("Frame", nil, Config)
	Config.GeneralModule:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.GeneralModule:SetPoint("TOPLEFT", 8, -8)
	Config.GeneralModule:SetSize(380, 300)

	------------------------------------------------------------------------------------------------------------------------------
	Config.InteractModule.Header = Config.InteractModule:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.InteractModule.Header:SetText(TUTORIAL.CONFIG.INTERACTHEADER)
	Config.InteractModule.Header:SetPoint("TOPLEFT", 16, -16)

	Config.InteractModule.Dude = Config.InteractModule:CreateTexture(nil, "BACKGROUND", nil, 1)
	Config.InteractModule.Dude:SetTexture("Interface\\TutorialFrame\\UI-TutorialFrame-QuestGiver")
	Config.InteractModule.Dude:SetPoint("CENTER", 0, 0)
	Config.InteractModule.Dude:SetSize(128, 128)

	Config.InteractModule.Hand = Config.InteractModule:CreateTexture(nil, "BACKGROUND", nil, 2)
	Config.InteractModule.Hand:SetTexture("Interface\\TutorialFrame\\UI-TutorialFrame-GloveCursor")
	Config.InteractModule.Hand:SetPoint("CENTER", 16, -40)
	Config.InteractModule.Hand:SetSize(64, 64)

	Config.InteractModule.Description = Config.InteractModule:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Config.InteractModule.Description:SetPoint("BOTTOM", 0, 32)
	Config.InteractModule.Description:SetText(TUTORIAL.CONFIG.INTERACTDESC)
	Config.InteractModule.Description:SetJustifyH("CENTER")

	Config.InteractModule.BindWrapper = db.Atlas.GetGlassWindow("$parentBindWrapper", Config.InteractModule, nil, true)
	Config.InteractModule.BindWrapper:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.InteractModule.BindWrapper:SetPoint("CENTER", 0, 8)
	Config.InteractModule.BindWrapper:SetSize(240, 140)
	Config.InteractModule.BindWrapper.Close:Hide()
	Config.InteractModule.BindWrapper:Hide()

	Config.InteractModule.BindCatcher = db.Atlas.GetFutureButton("$parentBindCatcher", Config.InteractModule.BindWrapper, nil, nil, 200)
	Config.InteractModule.BindCatcher.HighlightTexture:ClearAllPoints()
	Config.InteractModule.BindCatcher.HighlightTexture:SetAllPoints(Config.InteractModule.BindCatcher)
	Config.InteractModule.BindCatcher:SetHeight(108)
	Config.InteractModule.BindCatcher:SetPoint("CENTER", 0, 0)
	Config.InteractModule.BindCatcher:SetScript("OnClick", BindCatcherOnClick)
	Config.InteractModule.BindCatcher:SetScript("OnHide", BindCatcherOnHide)
	Config.InteractModule.BindCatcher:SetScript("OnShow", BindCatcherOnShow)
	Config.InteractModule.BindCatcher.Cover:Hide()
	-- Show it once to populate settings
	BindCatcherOnShow(Config.InteractModule.BindCatcher)

	Config.InteractModule.Enable = CreateFrame("CheckButton", nil, Config.InteractModule, "ChatConfigCheckButtonTemplate")
	Config.InteractModule.Enable:SetPoint("TOPLEFT", 16, -40)
	Config.InteractModule.Enable:SetChecked(Settings.interactWith)
	Config.InteractModule.Enable:SetScript("OnClick", function(self) InteractModuleOnShow(self:GetParent()) end)

	Config.InteractModule.Enable.Text = Config.InteractModule.Enable:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	Config.InteractModule.Enable.Text:SetText(TUTORIAL.CONFIG.INTERACTCHECK)
	Config.InteractModule.Enable.Text:SetPoint("LEFT", 30, 0)

	Config.InteractModule.MouseOver = CreateFrame("CheckButton", nil, Config.InteractModule, "ChatConfigCheckButtonTemplate")
	Config.InteractModule.MouseOver:SetPoint("BOTTOMLEFT", 16, 56)
	Config.InteractModule.MouseOver:SetChecked(Settings.mouseOverMode)
	Config.InteractModule.MouseOver:SetScript("OnClick", function(self) InteractModuleOnShow(self:GetParent()) end)

	Config.InteractModule.MouseOver.Text = Config.InteractModule.MouseOver:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	Config.InteractModule.MouseOver.Text:SetText(TUTORIAL.CONFIG.MOUSEOVERMODE)
	Config.InteractModule.MouseOver.Text:SetPoint("LEFT", 30, 0)

	------------------------------------------------------------------------------------------------------------------------------
	Config.MouseModule.Header = Config.MouseModule:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.MouseModule.Header:SetText(TUTORIAL.CONFIG.MOUSEHEADER)
	Config.MouseModule.Header:SetPoint("TOPLEFT", 16, -16)

	Config.Events = {}
	for i, setting in pairs(GetMouseSettings()) do
		local check = CreateFrame("CheckButton", "db.MouseEvent"..i, Config.MouseModule, "ChatConfigCheckButtonTemplate")
		local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetText(setting.desc)
		check:SetChecked(setting.toggle)
		check.Events = setting.event
		check.Description = text
		check:SetPoint("TOPLEFT", 16, -30*i-10)
		text:SetPoint("LEFT", check, 30, 0)
		check:Show()
		text:Show()
		tinsert(Config.Events, check)
	end

	------------------------------------------------------------------------------------------------------------------------------
	Config.GeneralModule.Header = Config.GeneralModule:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.GeneralModule.Header:SetText(TUTORIAL.CONFIG.GENERALHEADER)
	Config.GeneralModule.Header:SetPoint("TOPLEFT", 16, -16)

	local mouseCvarOffset = #Config.Events
	Config.General = {}
	for i, setting in pairs(GetAddonSettings()) do
		local check = CreateFrame("CheckButton", "$parentGeneralSetting"..i, Config.GeneralModule, "ChatConfigCheckButtonTemplate")
		local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetText(setting.desc)
		check:SetChecked(setting.toggle)
		check.Description = text
		check.Cvar = setting.cvar
		check.Reload = setting.needReload
		text:SetPoint("LEFT", check, 30, 0)
		check:Show()
		text:Show()
		if setting.mouse then
			mouseCvarOffset = mouseCvarOffset + 1
			check:SetPoint("TOPLEFT", Config.MouseModule, "TOPLEFT", 16, -30*mouseCvarOffset-10)
		else
			check:SetPoint("TOPLEFT", 16, -30*i-10)
		end
		tinsert(Config.General, check)
	end

	------------------------------------------------------------------------------------------------------------------------------

	Config.MultiChoiceModule = CreateFrame("Frame", nil, Config)
	Config.MultiChoiceModule:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.MultiChoiceModule:SetPoint("BOTTOMLEFT", 8, 8)
	Config.MultiChoiceModule:SetSize(500, 276)

	Config.TriggerHeader = Config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.TriggerHeader:SetText(TUTORIAL.CONFIG.TRIGGERHEADER)
	Config.TriggerHeader:SetPoint("TOPLEFT", Config.MultiChoiceModule, 16, -138)

	Config.Triggers = {}

	local triggerGraphics = {
		["Shift"] 	= {offset = -8, cvar = "shift"},
		["Ctrl"] 	= {offset = 120-12, cvar = "ctrl"},
		["1st"] 	= {offset = 240-14, cvar = "trigger1"},
		["2nd"] 	= {offset = 360-16, cvar = "trigger2"},
	}

	for name, info in pairs(triggerGraphics) do
		local trigger = Config:CreateTexture(nil, "ARTWORK")
		trigger:SetTexture("Interface\\TutorialFrame\\UI-TUTORIAL-FRAME")
		trigger:SetSize(76, 101)
		trigger:SetTexCoord(0.154296875, 0.30078125, 0.80078125, 1)
		trigger:SetPoint("TOPLEFT", Config.TriggerHeader, "TOPLEFT", info.offset, -24)
		trigger.Value = Settings[info.cvar]
		trigger.Cvar = info.cvar

		local triggerText = Config:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		triggerText:SetText(name)
		triggerText:SetPoint("CENTER", trigger, 0, 20)
		triggerText:SetTextColor(1, 0, 0, 1)

		tinsert(Config.Triggers, trigger)

		Config[name] = trigger
	end

	local TEXTURE_PATH = "Interface\\AddOns\\ConsolePort\\Controllers\\%s\\Icons32x32\\%s"
	local triggers = {
		CP_TL1 = format(TEXTURE_PATH, Settings.type, "CP_TL1"),
		CP_TL2 = format(TEXTURE_PATH, Settings.type, "CP_TL2"),
		CP_TR1 = format(TEXTURE_PATH, Settings.type, "CP_TR1"),
		CP_TR2 = format(TEXTURE_PATH, Settings.type, "CP_TR2"),
	}

	local radioButtons = {
		{parent = Config["Shift"],	default = Settings.shift},
		{parent = Config["Ctrl"], 	default = Settings.ctrl},
		{parent = Config["1st"], 	default = Settings.trigger1},
		{parent = Config["2nd"], 	default = Settings.trigger2},
	}

	local function CheckOnClick(self)
		for i, button in pairs(self.set) do
			button:SetChecked(false)
		end
		self:SetChecked(true)
		self.parent.Value = self.name
	end

	for i, radio in pairs(radioButtons) do
		local num = 1
		local radioset = {}
		for name, texture in db.pairsByKeys(triggers) do
			local button = CreateFrame("CheckButton", "$parentTrigger"..i..name, Config, "UIRadioButtonTemplate")
			button.set = radioset
			button.name = name
			button.parent = radio.parent
			button.text = button:CreateTexture(nil, "OVERLAY")
			button.text:SetTexture(texture)
			button.text:SetPoint("CENTER", 24, 0)
			button.text:SetSize(32, 32)
			button:SetPoint("TOPLEFT", radio.parent, "TOPRIGHT", -3, -24*(num-1)-8)
			if name == radio.default then
				radio.parent.Value = name
				button:SetChecked(true)
			else
				button:SetChecked(false)
			end
			tinsert(radioset, button)
			button:SetScript("OnClick", CheckOnClick)
			num = num + 1
		end
	end


	Config.CursorHeader = Config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.CursorHeader:SetText(TUTORIAL.CONFIG.VIRTUALCURSOR)
	Config.CursorHeader:SetPoint("TOPLEFT", Config.MultiChoiceModule, 16, -16)

	Config.LeftClick = Config:CreateTexture()
	Config.LeftClick:SetTexture("Interface\\TutorialFrame\\UI-TUTORIAL-FRAME")
	Config.LeftClick:SetSize(76*0.75, 101*0.75)
	Config.LeftClick:SetTexCoord(0.0019531, 0.1484375, 0.4257813, 0.6210938)
	Config.LeftClick:SetPoint("TOPLEFT", Config.CursorHeader, "TOPLEFT", 0, -24)

	Config.RightClick = Config:CreateTexture()
	Config.RightClick:SetTexture("Interface\\TutorialFrame\\UI-TUTORIAL-FRAME")
	Config.RightClick:SetSize(76*0.75, 101*0.75)
	Config.RightClick:SetTexCoord(0.0019531, 0.1484375, 0.6269531, 0.8222656)
	Config.RightClick:SetPoint("LEFT", Config.LeftClick, "RIGHT", 60, 0)

	Config.SpecialClick = Config:CreateTexture()
	Config.SpecialClick:SetTexture("Interface\\TutorialFrame\\UI-TUTORIAL-FRAME")
	Config.SpecialClick:SetSize(76*0.75, 101*0.75)
	Config.SpecialClick:SetTexCoord(0.1542969, 0.3007813, 0.2246094, 0.4199219)
	Config.SpecialClick:SetPoint("LEFT", Config.RightClick, "RIGHT", 60, 0)

	Config.ScrollClick = Config:CreateTexture()
	Config.ScrollClick:SetTexture("Interface\\TutorialFrame\\UI-TUTORIAL-FRAME")
	Config.ScrollClick:SetSize(76*0.75, 101*0.75)
	Config.ScrollClick:SetTexCoord(0.0019531, 0.1484375, 0.2246094, 0.4199219)
	Config.ScrollClick:SetPoint("LEFT", Config.SpecialClick, "RIGHT", 60, 0)

	local clickButtons 	= {
		CP_R_RIGHT 	= TEXTURE.CP_R_RIGHT,
		CP_R_LEFT 	= TEXTURE.CP_R_LEFT,
		CP_R_UP		= TEXTURE.CP_R_UP,
		CP_R_DOWN	= TEXTURE.CP_R_DOWN,
	}

	local scrollButtons = {
		CP_TL1 		= TEXTURE.CP_TL1,
		CP_TL2 		= TEXTURE.CP_TL2,
	}

	local radioButtons = {
		{parent = Config.LeftClick, 	selection = clickButtons,	default = db.Mouse.Cursor.Left},
		{parent = Config.RightClick, 	selection = clickButtons,	default = db.Mouse.Cursor.Right},
		{parent = Config.SpecialClick, 	selection = clickButtons, 	default = db.Mouse.Cursor.Special},
		{parent = Config.ScrollClick, 	selection = scrollButtons,	default = db.Mouse.Cursor.Scroll},
	}

	for i, radio in pairs(radioButtons) do
		local num = 1
		local radioSet = {}
		for name, texture in pairs(radio.selection) do
			local button = CreateFrame("CheckButton", addOn.."VirtualClick"..i..num, Config, "UIRadioButtonTemplate")

			button.text = button:CreateTexture(nil, "OVERLAY")
			button.text:SetTexture(gsub(texture, "Icons64x64", "Icons32x32"))
			button.text:SetPoint("CENTER", 24, 0)
			button.text:SetSize(32, 32)

			button:SetPoint("TOPLEFT", radio.parent, "TOPRIGHT", 8, -24*(num-1))
			if name == radio.default then
				radio.parent.button = name
				button:SetChecked(true)
			else
				button:SetChecked(false)
			end
			tinsert(radioSet, button)
			button:SetScript("OnClick", function(self)
				for i, button in pairs(radioSet) do
					button:SetChecked(false)
				end
				self:SetChecked(true)
				radio.parent.button = name
			end)
			num = num + 1
		end
	end


	Config.ActionBarModule = CreateFrame("Frame", nil, Config)
	Config.ActionBarModule:SetBackdrop(db.Atlas.Backdrops.Border)
	Config.ActionBarModule:SetPoint("BOTTOMLEFT", Config.MultiChoiceModule,"BOTTOMRIGHT", -8, 0)
	Config.ActionBarModule:SetSize(182, 276)
	Config.ActionBarModule.Styles = {}
	Config.ActionBarModule:SetID(1)

	Config.ActionBarModule.Header = Config.ActionBarModule:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	Config.ActionBarModule.Header:SetText(TUTORIAL.CONFIG.ACTIONBARHEADER)
	Config.ActionBarModule.Header:SetPoint("TOPLEFT", 16, -16)

	local class = select(2, UnitClass("player"))
	local classIcon = "Interface\\Icons\\ClassIcon_"..class

	local actionBarStyles = {
		[1] = {name = "CP_R_UP"},
		[2] = {name = "CP_R_DOWN"},
		[3] = {name = "CP_R_LEFT"},
		[4] = {name = "CP_R_RIGHT"},
	}

	local styles = Config.ActionBarModule.Styles

	for index, info in pairs(actionBarStyles) do
		local button = CreateFrame("CheckButton", "$parentStyle"..#Config.ActionBarModule.Styles+1, Config.ActionBarModule, "UIRadioButtonTemplate")

		button.mockButton1 = CreateFrame("Button", "$parentFakeActionButton1", button)
		button.mockButton1:SetPoint("LEFT", button, "RIGHT", 16, 0)
		button.mockButton1:SetSize(36, 36)
		button.mockButton1:SetScript("OnClick", function() button:Click() end)
		button.mockButton1:SetScript("OnShow", function(self)
			self:SetBackdrop({bgFile = _G["ActionButton"..index].icon:GetTexture() or classIcon})
		end)

		button.mockButton1.mod = "_NOMOD"
		button.mockButton1.name = info.name

		button.HotKey1 = ConsolePort.CreateHotKey(button.mockButton1, index)
		button.HotKey1:Show()
		button.HotKey1:SetPoint("TOPRIGHT", 0, 0)

		button.mockButton2 = CreateFrame("Button", "$parentFakeActionButton2", button)
		button.mockButton2:SetPoint("LEFT", button.mockButton1, "RIGHT", 16, 0)
		button.mockButton2:SetSize(36, 36)
		button.mockButton2:SetScript("OnClick", function() button:Click() end)
		button.mockButton2:SetScript("OnShow", function(self)
			self:SetBackdrop({bgFile = _G["ActionButton"..index+4].icon:GetTexture() or classIcon})
		end)

		button.mockButton2.mod = "_CTRLSH"
		button.mockButton2.name = info.name

		button.HotKey2 = ConsolePort.CreateHotKey(button.mockButton2, index)
		button.HotKey2:Show()
		button.HotKey2:SetPoint("TOPRIGHT", 0, 0)

		if info.func then
			info.func(button)
		end

		button:SetPoint("TOPLEFT", Config.ActionBarModule, "TOPLEFT", 16, -52*(index-1)-64)
		if ( index == Settings.actionBarStyle ) or ( index == 1 and not Settings.actionBarStyle ) then
			Config.ActionBarModule:SetID(index)
			button:SetChecked(true)
		else
			button:SetChecked(false)
		end
		tinsert(styles, button)
		button:SetScript("OnClick", function(self)
			for i, button in pairs(styles) do
				button:SetChecked(false)
			end
			self:SetChecked(true)
			Config.ActionBarModule:SetID(index)
		end)
	end

end})