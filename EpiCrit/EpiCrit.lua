-----------------------------------------------------------------------------------------------
-- EpiCrit - Critical hit tracking
-- Author: This super awesome guy
-- Curse: HawtChocolateDev
-- WildStar Forums: HawtChocolate
-- /ec slash command to restore
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Spell"
require "ActionSetLib"
require "AbilityBook"
 
-----------------------------------------------------------------------------------------------
-- EpiCrit Module Definition
-----------------------------------------------------------------------------------------------
local EpiCrit = {} 


-----------------------------------------------------------------------------------------------
-- Globals
-----------------------------------------------------------------------------------------------
tAddonVersion = {"1","0","7"}
strAddonVersion = tAddonVersion[1] .. "." .. tAddonVersion[2] .. "." .. tAddonVersion[3]

currentPlayer = nil
sPlayerName = nil
tAbilities = nil
tAppData = {}

tChannelList = {
	["Yell"] = "y",
	["Party"] = "p",
	["Zone"] = "z",
	["PvP"] = "v",
	["Guild"] = "g",
	["Instance"] = "i"
}
tSoundList = {
	["Ach"] = Sound.PlayUIAchievementGranted,
	["Gold"] = Sound.PlayUIChallengeGold,
	["Craft"] = Sound.PlayUICraftingSuccess,
	["Dung"] = Sound.PlayUIQueuePopsDungeon,
	["Adv"] = Sound.PlayUIQueuePopsAdventure
}
-----------------------------------------------------------------------------------------------
-- Helper Utilities
-----------------------------------------------------------------------------------------------
function EpiCrit:PostToDebugChannel(strText)
	ChatSystemLib.PostOnChannel(3, strText)
end
function EpiCrit:GetChild(wnd, strChild)
	return wnd:FindChild(strChild)
end
function EpiCrit:GetConfigChild(strChild)
	return self.wndConfig:FindChild(strChild)
end
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EpiCrit:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tDamageItems = {}
	o.tHealingItems = {}
	o.wndNewRecord = nil
	o.wndConfig = nil
	o.atNewRecord = ApolloTimer.Create(2, false, "OnNewRecordDestroy", o)

    return o
end

function EpiCrit:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
	Apollo.RegisterEventHandler("DamageOrHealingDone","OnDamageOrHealing", self)

end
 
function EpiCrit:OnCharCreated()
currentPlayer = GameLib.GetPlayerUnit()
sPlayerName = GameLib.GetPlayerUnit():GetName()
self.nCurrentMode = tAppData.tUserPrefs.nDefaultMode or 0
end
-----------------------------------------------------------------------------------------------
-- EpiCrit OnLoad
-----------------------------------------------------------------------------------------------
function EpiCrit:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EpiCrit.xml")
	
	self.wndNewRecord = Apollo.LoadForm(self.xmlDoc, "EpiCritGranted", nil, self)
	self.wndConfig = Apollo.LoadForm(self.xmlDoc, "EpiCritConfig", nil, self)
	--Not sure why I am having to hide the form, it should not show automatically.
	self.wndNewRecord:Show(false, true)
	self.wndConfig:Show(false, true)
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- EpiCrit OnDocLoaded
-----------------------------------------------------------------------------------------------
function EpiCrit:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EpiCritHud", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndItemList = self.wndMain:FindChild("EcList")
		

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		self.wndMain:SetSizingMinimum(340,340)
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("ec", "OnEpiCrit", self)
		Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
		
		-- Do additional Addon initialization here
			--Get Player Name

	currentPlayer = GameLib.GetPlayerUnit()
	if not currentPlayer then
		Apollo.RegisterEventHandler("CharacterCreated","OnCharCreated",self)
	else
	sPlayerName = GameLib.GetPlayerUnit():GetName()
		self.nCurrentMode = tAppData.tUserPrefs.nDefaultMode or 0
	end
		self.wndMain:Show(tAppData.tUserPrefs.bDisplayWindow, true)
	end
end

function EpiCrit:OnWindowManagementReady()
    Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "EpiCrit"})
	if tAppData.tUserPrefs.bDisplayWindow then
		self:BuildItemList(self.nCurrentMode)
	end

end
-----------------------------------------------------------------------------------------------
-- EpiCrit Functions
-----------------------------------------------------------------------------------------------
function EpiCrit:OnEpiCrit()
	self.wndMain:Invoke()
end

function EpiCrit:OnConfig()
	self.wndConfig:Show(not self.wndConfig:IsVisible(), true)
	self.wndConfig:ToFront()
	self:SaveConfig()
end

-----------------------------------------------------------------------------------------------
-- EpiCrit Defaults
-----------------------------------------------------------------------------------------------

-- Default Damage Data Structure
function EpiCrit:GetDefaultDamageData()
local tDefaultDamageData = {
	sSpellName = "Unknown",
	tNorm = {
		nSpellDamage = 0,
		sTargetName = "No Target",
		nTargetLevel = 0,
		nNumSuccess = 0,
		sRecordTime = "",
		sLastTargetName = "None",
		nLastTargetLevel = 0,
		nLastSpellDamage = 0,
		sRecordZone = "No Zone"
	},
	tCrit = {
		nSpellDamage = 0,
		sTargetName = "No Target",
		nTargetLevel = 0,
		nNumSuccess = 0,
		sRecordTime = "",
		sLastTargetName = "None",
		nLastTargetLevel = 0,
		nLastSpellDamage = 0,
		sRecordZone = "No Zone"
	}
}
return tDefaultDamageData
end
--Defautl App Data
function EpiCrit:GetDefaultAppData()
local appData = {
	tUserPrefs = {
		tNotificationLocation = {},
		bStickyRecords = false,
		bDisplayWindow = false,
		nDefaultMode = 0,
		bDisplayNotification = true,
		bAutoTrackNewSkills = true,
		tExcludedSkills = {},
		bPlaySound = false,
		bAnnounce = false,
		tAnnounceChannels = {},
		strAnnounceSound = nil,
		bPostToWhisper = false,
		strAnnounceFormat = "$p achieved a new critical hit record! By casting $s on $t for $d damage!"
	},
	tDamageData = {},
	tHealingData = {}
}
return appData
end
---------------------------------------------------------------------------------------------------
-- EpiCritHud Functions
---------------------------------------------------------------------------------------------------

function EpiCrit:DisplayNotificationChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bDisplayNotification = wndControl:IsChecked()
end


function EpiCrit:EnableStickyRecordsChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bStickyRecords = wndControl:IsChecked()
end

function EpiCrit:DisplayWindowChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bDisplayWindow = wndControl:IsChecked()
end

---------------------------------------------------------------------------------------------------
-- EpiCritListItem Functions
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- ExcludedSkillListItem Functions
---------------------------------------------------------------------------------------------------

function EpiCrit:ExcludedSkillChecked( wndHandler, wndControl, eMouseButton )
	local tData = wndControl:GetData()
	if tData then
		tAppData.tUserPrefs.tExcludedSkills[tData.strName] = wndControl:IsChecked()
	end
end

---------------------------------------------------------------------------------------------------
-- EpiCritConfig Functions
---------------------------------------------------------------------------------------------------

function EpiCrit:OnToggleSoundsClicked( wndHandler, wndControl, eMouseButton )
	local wndSounds = self.wndConfig:FindChild("Sounds")
	
	if tAppData.tUserPrefs.strAnnounceSound ~= nil then
	local chkSound = wndSounds:FindChild(tAppData.tUserPrefs.strAnnounceSound)
	chkSound:SetCheck(true)
	end
	
	wndSounds:Show(true, true)
end

function EpiCrit:OnToggleChannelsClicked( wndHandler, wndControl, eMouseButton )

	if tAppData.tUserPrefs.tAnnounceChannels == nil then
		tAppData.tUserPrefs.tAnnounceChannels = {}
	end
	
	local wndChannels = self.wndConfig:FindChild("ChatChannels")
	
	local chkYell = wndChannels:FindChild("Yell")
	chkYell:SetCheck(tAppData.tUserPrefs.tAnnounceChannels[chkYell:GetName()])
	
	local chkParty = wndChannels:FindChild("Party")
	chkParty:SetCheck(tAppData.tUserPrefs.tAnnounceChannels[chkParty:GetName()])
	
	local chkZone  = wndChannels:FindChild("Zone")
	chkZone:SetCheck(tAppData.tUserPrefs.tAnnounceChannels[chkZone:GetName()])
	
	local chkGuild = wndChannels:FindChild("Guild")
	chkGuild:SetCheck(tAppData.tUserPrefs.tAnnounceChannels[chkGuild:GetName()])
	
	local chkInstance = wndChannels:FindChild("Instance")
	chkInstance:SetCheck(tAppData.tUserPrefs.tAnnounceChannels[chkInstance:GetName()])

	wndChannels:Show(true, true)
end

function EpiCrit:OnAnnounceTextFormatChanging( wndHandler, wndControl, strNewText, strOldText, bAllowed )
end

function EpiCrit:OnAnnounceTextFormatEscaped( wndHandler, wndControl )
end

function EpiCrit:OnCloseConfiguration( wndHandler, wndControl, eMouseButton )
	self:SaveConfig()
	self.wndConfig:Show(false, true)
end

function EpiCrit:SaveConfig()

	local chkDisplayWindow = self:GetConfigChild("ChkWindowDisplay")
	tAppData.tUserPrefs.bDisplayWindow = chkDisplayWindow:IsChecked()
	
	local chkStickyRecords = self:GetConfigChild("ChkStickyRecords")
	tAppData.tUserPrefs.bStickyRecords = chkStickyRecords:IsChecked()
	
	local chkDisplayNotif = self:GetConfigChild("ChkDisplayNotif")
	tAppData.tUserPrefs.bDisplayNotification = chkDisplayNotif:IsChecked()
	
	local chkPostWhisper = self:GetConfigChild("ChkPostWhisper")
	tAppData.tUserPrefs.bPostToWhisper = chkPostWhisper:IsChecked()
	
	local chkPlaySound = self:GetConfigChild("ChkPlaySound")
	tAppData.tUserPrefs.bPlaySound = chkPlaySound:IsChecked()
	
	local chkAnnounce = self:GetConfigChild("ChkAnnounce")
	tAppData.tUserPrefs.bAnnounce = chkAnnounce:IsChecked()
	
	local textBoxAnnounceFormat = self:GetConfigChild("TextBoxAnnounceFormat")
	tAppData.tUserPrefs.strAnnounceFormat = textBoxAnnounceFormat:GetText()
	
	if self.wndNewRecord:IsVisible() then
		self:SetNotificationPosition()
	end
	
	local doNotTrackList = self:GetConfigChild("DoNotTrackList")
	local chatChannels = self:GetConfigChild("ChatChannels")
	local sounds = self:GetConfigChild("Sounds")
	
end

function EpiCrit:OnChatChannelChecked( wndHandler, wndControl, eMouseButton )
	if tAppData.tUserPrefs.tAnnounceChannels == nil then
		tAppData.tUserPrefs.tAnnounceChannels = {}
	end
	
	tAppData.tUserPrefs.tAnnounceChannels[wndControl:GetName()] = wndControl:IsChecked()
end

function EpiCrit:OnSoundChecked( wndHandler, wndControl, eMouseButton )
	if wndControl:IsChecked() then
		tAppData.tUserPrefs.strAnnounceSound = wndControl:GetName()
	else
		tAppData.tUserPrefs.strAnnounceSound = nil
	end
end

function EpiCrit:PostWhisperChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bPostToWhisper = wndControl:IsChecked()
end

function EpiCrit:PlaySoundChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bPlaySound = wndControl:IsChecked()
end

function EpiCrit:AnnounceChecked( wndHandler, wndControl, eMouseButton )
	tAppData.tUserPrefs.bAnnounce = wndControl:IsChecked()
end

function EpiCrit:DefaultModeChecked( wndHandler, wndControl, eMouseButton )

if wndControl:GetName() == "ChkDefaultDamage" then
	tAppData.tUserPrefs.nDefaultMode = 0
elseif wndControl:GetName() == "ChkDefaultHealing" then
	tAppData.tUserPrefs.nDefaultMode = 1
end

end

function EpiCrit:SetNotificationPosition()
	if not self.wndNewRecord:IsVisible() then
		if (tAppData.tUserPrefs.tNotificationLocation ~= nil and tableLength(tAppData.tUserPrefs.tNotificationLocation) > 0) then
			local tPoints = tAppData.tUserPrefs.tNotificationLocation.fPoints
			local tOffsets = tAppData.tUserPrefs.tNotificationLocation.nOffsets
			
			self.wndNewRecord:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[4])
			self.wndNewRecord:SetAnchorPoints(tPoints[1], tPoints[2], tPoints[3], tPoints[4])
		else
			local tDefaultLoc = {
					fPoints = {0.5,0,0.5,0},
					nOffsets = {-200,50,200,125}
				}
			local tPoints = tDefaultLoc.fPoints
			local tOffsets = tDefaultLoc.nOffsets
					
			self.wndNewRecord:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[4])
			self.wndNewRecord:SetAnchorPoints(tPoints[1], tPoints[2], tPoints[3], tPoints[4])
		end		
		self.wndNewRecord:SetStyle("Moveable", true)
		self.wndNewRecord:SetStyle("Sizable", true)
		self.wndNewRecord:Show(true, true)
	else
		tAppData.tUserPrefs.tNotificationLocation = self.wndNewRecord:GetLocation():ToTable()		
		self.wndNewRecord:SetStyle("Moveable", false)
		self.wndNewRecord:SetStyle("Sizable", false)
		self.wndNewRecord:Show(false, true)
	end
end
function EpiCrit:OnSetNotificationPosition( wndHandler, wndControl, eMouseButton )
	self:SetNotificationPosition()
end

function EpiCrit:RestoreDefaults( wndHandler, wndControl, eMouseButton )
	self:SetDefaultNotificationPosition()
	tAppData = self:GetDefaultAppData()
	self:SetConfigurationPanel()
end
function EpiCrit:SetDefaultNotificationPosition()
	local tDefaultLoc = {
	fPoints = {0.5,0,0.5,0},
	nOffsets = {-200,50,200,125}
}
	tAppData.tUserPrefs.tNotificationLocation = tDefaultLoc
	local tPoints = tAppData.tUserPrefs.tNotificationLocation.fPoints
	local tOffsets = tAppData.tUserPrefs.tNotificationLocation.nOffsets
			
	self.wndNewRecord:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[4])
	self.wndNewRecord:SetAnchorPoints(tPoints[1], tPoints[2], tPoints[3], tPoints[4])
end
function EpiCrit:OnResetNotificationPosition( wndHandler, wndControl, eMouseButton )
	self:SetDefaultNotificationPosition()
end

-----------------------------------------------------------------------------------------------
-- EpiCrit Instance
-----------------------------------------------------------------------------------------------
local EpiCritInst = EpiCrit:new()
EpiCritInst:Init()

-----------------------------------------------------------------------------------------------
-- EpiCrit Imp
-----------------------------------------------------------------------------------------------

function EpiCrit:OnDamageOrHealing( unitCaster, unitTarget, eDamageType, nDamage, nShieldDamaged, nAbsorptionAmount, bCritical, strSpellName )
if not unitCaster then
	return
end

if not unitTarget then
	return
end

--if bCritical and strSpellName == "Electrocute" then
--	ChatSystemLib.PostOnChannel(3, "E Crit")
--end

local sSpellName = strSpellName --tEventArgs.splCallingSpell:GetName()
local sTargetName = unitTarget:GetName()
local sCaster = unitCaster:GetName()

if(sCaster == sPlayerName) then

local wndDetails = self.wndMain:FindChild("ExtInfoPopout")

if (not unitCaster:IsPvpFlagged() and not tAppData.tUserPrefs.bStickyRecords and wndDetails:IsVisible()) then
	wndDetails:Show(false, true)
end

local tSkills = tAppData.tUserPrefs.tExcludedSkills
			
			if tSkills then
				for sk, sv in pairs(tSkills) do
					if(sk == sSpellName and sv == true) then
						return
					end
				end
			end

tDamage = self:GetDefaultDamageData()

local nTargetLevel = unitTarget:GetLevel()

tDamage.sSpellName = sSpellName

local bIsCritical = bCritical

if nShieldDamaged and nShieldDamaged > 0 then
	nDamage = nDamage + nShieldDamaged
end

if bIsCritical then
	tDamage.tCrit.nSpellDamage = nDamage
	tDamage.tCrit.nTargetLevel = nTargetLevel
	tDamage.tCrit.sTargetName = sTargetName
	tDamage.tCrit.nNumSuccess = 1
	tDamage.tCrit.sRecordZone = GameLib.GetCurrentZoneMap().strName
	tDamage.tCrit.sRecordTime = Time.Now():__tostring()
else
	tDamage.tNorm.nSpellDamage = nDamage
	tDamage.tNorm.nTargetLevel = nTargetLevel
	tDamage.tNorm.sTargetName = sTargetName
	tDamage.tNorm.nNumSuccess = 1
	tDamage.tNorm.sRecordZone = GameLib.GetCurrentZoneMap().strName
	tDamage.tNorm.sRecordTime = Time.Now():__tostring()
end
		
	local bFirstRecord = nil
	local oEcDamage = nil
	
	if (eDamageType == GameLib.CodeEnumDamageType.Physical
		or eDamageType == GameLib.CodeEnumDamageType.Magic
		or eDamageType == GameLib.CodeEnumDamageType.Tech ) then
		
		bFirstRecord = tAppData.tDamageData[sSpellName] == nil
		
		if bFirstRecord then
			tAppData.tDamageData[sSpellName] = tDamage
			oEcDamage = tAppData.tDamageData[sSpellName]
		else
			oEcDamage = tAppData.tDamageData[sSpellName]
		end
		
	elseif (eDamageType == GameLib.CodeEnumDamageType.Heal 
				or eDamageType == GameLib.CodeEnumDamageType.HealShields) then

		bFirstRecord = tAppData.tHealingData[sSpellName] == nil
		if bFirstRecord then
			tAppData.tHealingData[sSpellName] = tDamage
			oEcDamage = tAppData.tHealingData[sSpellName]
		else
			oEcDamage = tAppData.tHealingData[sSpellName]
		end
		
	end
	
	--NEW ATTEMPTS
	if bIsCritical then
		oEcDamage.tCrit.nLastSpellDamage = nDamage
		oEcDamage.tCrit.sLastTargetName = sTargetName
		oEcDamage.tCrit.nLastTargetLevel = nTargetLevel
	else
		oEcDamage.tNorm.nLastSpellDamage = nDamage
		oEcDamage.tNorm.sLastTargetName = sTargetName
		oEcDamage.tNorm.nLastTargetLevel = nTargetLevel
	end
	local bRefresh = false
	--NEW RECORDS
	if(nDamage > oEcDamage.tCrit.nSpellDamage and bIsCritical) then
		bRefresh = true
		oEcDamage.tCrit.sRecordZone = GameLib.GetCurrentZoneMap().strName
		oEcDamage.tCrit.sRecordTime = Time.Now():__tostring()
		oEcDamage.tCrit.nSpellDamage = nDamage
		oEcDamage.tCrit.sTargetName = sTargetName
		oEcDamage.tCrit.nTargetLevel = nTargetLevel
		oEcDamage.tCrit.nNumSuccess = oEcDamage.tCrit.nNumSuccess + 1
		self:OnNewRecord(true, oEcDamage)
	elseif(nDamage > oEcDamage.tNorm.nSpellDamage) then
		bRefresh = true
		oEcDamage.tNorm.sRecordZone = GameLib.GetCurrentZoneMap().strName
		oEcDamage.tNorm.sRecordTime = Time.Now():__tostring()
		oEcDamage.tNorm.nSpellDamage = nDamage
		oEcDamage.tNorm.sTargetName = sTargetName
		oEcDamage.tNorm.nTargetLevel = nTargetLevel
		oEcDamage.tNorm.nNumSuccess = oEcDamage.tNorm.nNumSuccess + 1
		self:OnNewRecord(false, oEcDamage)

	end
	
	if bFirstRecord then
		if bIsCritical then
			self:OnNewRecord(true, oEcDamage)
		else
			self:OnNewRecord(false, oEcDamage)
		end
	end
	
	if (wndDetails:IsVisible() and bRefresh) then
		self:BuildOrUpdateDetailsPanel(oEcDamage, wndDetails, false)
	end
	--if bRefresh then
	self:BuildItemList(self.nCurrentMode)
	--end
end

end

function EpiCrit:OnNewRecordDestroy()
	self.wndNewRecord:Show(false, true)
end

function EpiCrit:OnNewRecord(bIsCritical,oEcDamage)
	if tAppData.tUserPrefs.bDisplayNotification then
		
		local wndRecordLabel = self.wndNewRecord:FindChild("NewRecordDialog")
		local recordText = nil
		
		if bIsCritical then
			recordText = string.format("%s with %s critical damage", oEcDamage.sSpellName, oEcDamage.tCrit.nSpellDamage)
		else
			recordText = string.format("%s with %s normal damage", oEcDamage.sSpellName, oEcDamage.tNorm.nSpellDamage)
		end
		
		wndRecordLabel:SetText(recordText)
		
		if (tAppData.tUserPrefs.tNotificationLocation ~= nil and tableLength(tAppData.tUserPrefs.tNotificationLocation) > 0) then
			local tPoints = tAppData.tUserPrefs.tNotificationLocation.fPoints
			local tOffsets = tAppData.tUserPrefs.tNotificationLocation.nOffsets
			
			self.wndNewRecord:SetAnchorOffsets(tOffsets[1], tOffsets[2], tOffsets[3], tOffsets[4])
			self.wndNewRecord:SetAnchorPoints(tPoints[1], tPoints[2], tPoints[3], tPoints[4])
		end
		self.wndNewRecord:Show(true, true)
		self.atNewRecord:Start()
	end
	
	local strText = tAppData.tUserPrefs.strAnnounceFormat
	
	strText = string.gsub(strText, "$p", sPlayerName or "Somebody Special")
	strText = string.gsub(strText, "$s", oEcDamage.sSpellName or "Supaa Spell")
	strText = string.gsub(strText, "$t", oEcDamage.tCrit.sTargetName or "Some Bad Guy")
	strText = string.gsub(strText, "$d", tostring(oEcDamage.tCrit.nSpellDamage) or "1")
	
	if (tAppData.tUserPrefs.bAnnounce and bIsCritical) then
		for k,v in pairs(tAppData.tUserPrefs.tAnnounceChannels) do
			if v == true then
				ChatSystemLib.Command(("/%s %s"):format(tChannelList[k], strText))
			end
		end
	end
	if (tAppData.tUserPrefs.bPostToWhisper and bIsCritical) then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, strText)
	end
	if (tAppData.tUserPrefs.bPlaySound and bIsCritical) then 
		Sound.Play(tSoundList[tAppData.tUserPrefs.strAnnounceSound])
	end
end

function EpiCrit:DestroyItemList()
	-- destroy all the wnd inside the list
	for k,v in pairs(self.tDamageItems) do
		v:Destroy()
	end
		for k,v in pairs(self.tHealingItems) do
		v:Destroy()
	end
	-- clear the list item array
	self.tDamageItems = {}
	self.tHealingItems = {}
end
function EpiCrit:HideItemsInList(nMode)
if(nMode == 0) then
for k, w in pairs(self.tDamageItems) do
 w:Show(false, true)
end
elseif(nMode == 1) then
for k, w in pairs(self.tHealingItems) do
 w:Show(false, true)
end
end

end
function EpiCrit:BuildItemList(nMode)

--self:DestroyItemList()

if(nMode == 0) then
for k, v in pairs(tAppData.tDamageData) do
 self:GenerateListItem(k,v,0)
end
elseif(nMode == 1) then
for k, v in pairs(tAppData.tHealingData) do
 self:GenerateListItem(k,v,1)
end
end
	self.wndItemList:ArrangeChildrenVert()
end


function EpiCrit:GenerateListItem(key, tData, nMode)
	-- load the window item for the list item
	local wnd = nil
	local items = nil
	if nMode == 0 then
		items = self.tDamageItems
	elseif nMode == 1 then
		items = self.tHealingItems
	else
		return
	end
	
	if items[key] == nil then
		wnd = Apollo.LoadForm(self.xmlDoc, "EpiCritListItem", self.wndItemList, self)
		wnd:SetAnchorPoints(0,0,1,0)
		wnd:SetAnchorOffsets(0,0,0,67)
		-- keep track of the window item created
		items[key] = wnd
	else
		wnd = items[key]
	end
	-- give it a piece of data to refer to 
	local wndSkillName = wnd:FindChild("SkillName")
	local wndNmlDmgVal = wnd:FindChild("NormalDmgValue")
	local wndNmlDmgTar = wnd:FindChild("NormalDmgTarget")
	local wndCritDmgVal = wnd:FindChild("CritDmgValue")
	local wndCritDmgTar = wnd:FindChild("CritDmgTarget")
	local btnDetails = wnd:FindChild("DetailsButton")
	
	local nSkillId = 0
	
	if not tAbilities then
		tAbilities = AbilityBook.GetAbilitiesList()
	end
		
	for k, v in pairs(tAbilities) do
		if(v.strName == tData.sSpellName) then
			nSkillId = v.nId
			break
		end
	end
	
	local wndSkillIcon = wnd:FindChild("AbilityItemWindow"):SetAbilityId(nSkillId)

	btnDetails:SetContentType(key)

	wndSkillName:SetText(tData.sSpellName)
	wndNmlDmgVal:SetText(tostring(tData.tNorm.nSpellDamage))
	wndNmlDmgTar:SetText(tData.tNorm.sTargetName)
	wndCritDmgVal:SetText(tostring(tData.tCrit.nSpellDamage))
	wndCritDmgTar:SetText(tData.tCrit.sTargetName)
	
	if not wnd:IsVisible() then
		wnd:Show(true, true)
	end
	--wnd:SetData(i)
end

function EpiCrit:OnSave(eType)
  -- eType is one of:
  -- GameLib.CodeEnumAddonSaveLevel.General
  -- GameLib.CodeEnumAddonSaveLevel.Account
  -- GameLib.CodeEnumAddonSaveLevel.Realm
  -- GameLib.CodeEnumAddonSaveLevel.Character
 
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    return tAppData
  end
end


function tableLength(T)
	local count = 0
	for _ in pairs(T) do count = count +1 end
	return count
end

 
function EpiCrit:OnRestore(eType, tSavedData)
if tSavedData == nil or tableLength(tSavedData) <= 0 then
	self:PostToDebugChannel("No saved data")
	tSavedData = self:GetDefaultAppData()
end
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    for k,v in pairs(tSavedData) do
      tAppData[k] = v
    end
  end
end

function EpiCrit:BuildOrUpdateDetailsPanel(tData, wndDetails, bReset)
	local extTitle = wndDetails:FindChild("Title")
	
	if (extTitle:GetText() == tData.sSpellName or bReset) then
	
	local wndNormStats = wndDetails:FindChild("NormalStats")
	local wndCritStats = wndDetails:FindChild("CritStats")
	
	extTitle:SetText(tData.sSpellName)
	
	--SET NORM STATS
	local wndNormTime = wndNormStats:FindChild("Timestamp")
	wndNormTime:SetText(string.format("Record Time: %s",tData.tNorm.sRecordTime))
	local wndNormRecordTarget = wndNormStats:FindChild("RecordTarget")
	wndNormRecordTarget:SetText(string.format("Record Target: %s(%s)",tData.tNorm.sTargetName, tData.tNorm.nTargetLevel or 0))
	local wndNormAttempts = wndNormStats:FindChild("Attempts")
	wndNormAttempts:SetText(string.format("Successful Records: %s",tData.tNorm.nNumSuccess))
	local wndNormLastHit = wndNormStats:FindChild("LastHit")
	wndNormLastHit:SetText(string.format("Last Attempt Hit: %s",tData.tNorm.nLastSpellDamage))
	local wndNormLastTarget = wndNormStats:FindChild("LastTarget")
	wndNormLastTarget:SetText(string.format("Last Attempt Target: %s(%s)",tData.tNorm.sLastTargetName, tData.tNorm.nLastTargetLevel or 0))
	local wndNormRecordZone = wndNormStats:FindChild("RecordZone")
	wndNormRecordZone:SetText(string.format("Record Zone: %s",tData.tNorm.sRecordZone or ""))
	local wndNormRecord = wndNormStats:FindChild("NormalRecord")
	local wndNormalRecordVal = wndNormRecord:FindChild("NormRecordVal")
	wndNormalRecordVal:SetText(string.format("%s",tData.tNorm.nSpellDamage))
	
	--SET CRIT STATS
	local wndCritTime = wndCritStats:FindChild("Timestamp")
	wndCritTime:SetText(string.format("Record Time: %s",tData.tCrit.sRecordTime))
	local wndCritRecordTarget = wndCritStats:FindChild("RecordTarget")
	wndCritRecordTarget:SetText(string.format("Record Target: %s(%s)",tData.tCrit.sTargetName, tData.tCrit.nTargetLevel or 0))
	local wndCritAttempts = wndCritStats:FindChild("Attempts")
	wndCritAttempts:SetText(string.format("Successful Records: %s",tData.tCrit.nNumSuccess))
	local wndCritLastHit = wndCritStats:FindChild("LastHit")
	wndCritLastHit:SetText(string.format("Last Attempt Hit: %s",tData.tCrit.nLastSpellDamage))
	local wndCritLastTarget = wndCritStats:FindChild("LastTarget")
	wndCritLastTarget:SetText(string.format("Last Attempt Target: %s(%s)",tData.tCrit.sLastTargetName, tData.tCrit.nLastTargetLevel or 0))
	local wndCritRecordZone = wndCritStats:FindChild("RecordZone")
	wndCritRecordZone:SetText(string.format("Record Zone: %s",tData.tCrit.sRecordZone or ""))
	local wndCritRecord = wndCritStats:FindChild("CritRecord")
	local wndCritalRecordVal = wndCritRecord:FindChild("CritRecordVal")
	wndCritalRecordVal:SetText(string.format("%s",tData.tCrit.nSpellDamage))
	
	end

end
--Button Handlers
function EpiCrit:ShowRecordDetails( wndHandler, wndControl, eMouseButton )
	
	local key = wndControl:GetContentType()
	local tData = {}
	
	local wndDetails = self.wndMain:FindChild("ExtInfoPopout")
	local extTitle = wndDetails:FindChild("Title")
	
	if(not wndDetails:IsVisible()) then
		wndDetails:Show(true, true)
		--wndDetails:ToFront()
	elseif(extTitle:GetText() == key) then
		wndDetails:Show(false, true)
	end
	
	if(self.nCurrentMode == 0) then
		tData = tAppData.tDamageData[key]
	elseif(self.nCurrentMode == 1) then
		tData = tAppData.tHealingData[key]
	end

	self:BuildOrUpdateDetailsPanel(tData, wndDetails, true)
		
end
function EpiCrit:ShowHealing( wndHandler, wndControl, eMouseButton )
	self.nCurrentMode = 1
	self:HideItemsInList(0)
	self:BuildItemList(self.nCurrentMode)
end

function EpiCrit:ShowDamage( wndHandler, wndControl, eMouseButton )
	self.nCurrentMode = 0
	self:HideItemsInList(1)
	self:BuildItemList(self.nCurrentMode)
end

function EpiCrit:Reset( wndHandler, wndControl, eMouseButton )
	tAppData.tDamageData = {}
	tAppData.tHealingData = {}
	self:DestroyItemList()
	--self:BuildItemList(tAppData.tUserPrefs.nDefaultMode)
end
function EpiCrit:SetConfigurationPanel()
	local chkDisplayNotif = self.wndConfig:FindChild("ChkDisplayNotif")
	chkDisplayNotif:SetCheck(tAppData.tUserPrefs.bDisplayNotification)
	
	local chkWinDisplay = self.wndConfig:FindChild("ChkWindowDisplay")
	chkWinDisplay:SetCheck(tAppData.tUserPrefs.bDisplayWindow)
	
	local chkStickyRecords = self.wndConfig:FindChild("ChkStickyRecords")
	chkStickyRecords:SetCheck(tAppData.tUserPrefs.bStickyRecords)

	if (tAppData.tUserPrefs.nDefaultMode == 0) then
		local chkDefaultMode = self.wndConfig:FindChild("ChkDefaultDamage")
		chkDefaultMode:SetCheck(true)
	elseif (tAppData.tUserPrefs.nDefaultMode == 1) then
		local chkDefaultMode = self.wndConfig:FindChild("ChkDefaultHealing")
		chkDefaultMode:SetCheck(true)
	end
	
	local chkAnnounce = self.wndConfig:FindChild("ChkAnnounce")
	chkAnnounce:SetCheck(tAppData.tUserPrefs.bAnnounce)

	local chkWhisper = self.wndConfig:FindChild("ChkPostWhisper")
	chkWhisper:SetCheck(tAppData.tUserPrefs.bPostToWhisper)
	
	local chkSound = self.wndConfig:FindChild("ChkPlaySound")
	chkSound:SetCheck(tAppData.tUserPrefs.bPlaySound)
	
	local textFormat = self.wndConfig:FindChild("TextBoxAnnounceFormat")
	if tAppData.tUserPrefs.strAnnounceFormat ~= nil then
		textFormat:SetText(tAppData.tUserPrefs.strAnnounceFormat)
	else
		textFormat:SetText("$p achieved a new critical hit record! By casting $s on $t for $d damage!")
	end
	
	local strAddonInfoText = string.format("EpiCrit Version: %s", strAddonVersion)
	local wndVersion = self.wndConfig:FindChild("AddonInfo")
	wndVersion:SetText(strAddonInfoText)
	
	local wndExc = self.wndConfig:FindChild("DoNotTrackList")
	if not tAbilities then
		tAbilities = AbilityBook.GetAbilitiesList()
	end
	
		for k, v in pairs(tAbilities) do
			if(v.bIsActive and v.nMaxTiers > 1) then
			local wnd = Apollo.LoadForm(self.xmlDoc, "ExcludedSkillListItem", wndExc, self)
			local chkExclude = wnd:FindChild("ChkExclude")
			
			local tSkills = tAppData.tUserPrefs.tExcludedSkills
			
			if tSkills then
				for sk, sv in pairs(tSkills) do
					if(sk == v.strName) then
						chkExclude:SetCheck(sv or false)
					end
				end
			end
			
			wnd:SetText(v.strName)
			chkExclude:SetData(v)
			end
		end
		
	wndExc:ArrangeChildrenVert()
end
function EpiCrit:ToggleConfigurationPanel( wndHandler, wndControl, eMouseButton )
	self:SetConfigurationPanel()
	self:OnConfig()
	
end

-- when the OK button is clicked
function EpiCrit:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function EpiCrit:OnCancel()
	self.wndMain:Close() -- hide the window
end

function EpiCrit:ExpandCollapse( wndHandler, wndControl, eMouseButton )

if bExpanded then
local offsets = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(offsets.left, offsets.top, offsets.right, 50)
	bExpanded = false
else
end

end
