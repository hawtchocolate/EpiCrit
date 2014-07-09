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
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Globals
-----------------------------------------------------------------------------------------------
tAddonVersion = {"1","0","3"}
strAddonVersion = "v" .. tAddonVersion[1] .. "." .. tAddonVersion[2] .. "." .. tAddonVersion[3]
currentPlayer = nil
sPlayerName = nil
tAbilities = nil
tAppData = {
	tUserPrefs = {
		bStickyRecords = false,
		bDisplayWindow = false,
		nDefaultMode = 0,
		bDisplayNotification = true,
		bAutoTrackNewSkills = true,
		tExcludedSkills = {}
	},
	tDamageData = {},
	tHealingData = {}
}
bExpanded = true
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EpiCrit:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {}
	o.wndNewRecord = nil
	o.atNewRecord = ApolloTimer.Create(2, false, "OnNewRecordDestroy", o)
	o.nCurrentMode = tAppData.tUserPrefs.nDefaultMode or 0	
    return o
end

function EpiCrit:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

	--Get Player Name
	currentPlayer = GameLib.GetPlayerUnit()
	if not currentPlayer then
		Apollo.RegisterEventHandler("CharacterCreated","OnCharCreated",self)
	else
	sPlayerName = GameLib.GetPlayerUnit():GetName()
		self.nCurrentMode = tAppData.tUserPrefs.nDefaultMode or 0
	end
	
	--Register Combat Events
	Apollo.RegisterEventHandler("CombatLogDamage","OnCombatLogDamage", self)
	Apollo.RegisterEventHandler("CombatLogHeal","OnCombatLogHeal", self)
	
end
 
function EpiCrit:OnCharCreated()
currentPlayer = GameLib.GetPlayerUnit()
sPlayerName = GameLib.GetPlayerUnit():GetName()
	self.nCurrentMode = tAppData.tUserPrefs.nDefaultMode or 0
	--self:BuildItemList(self.nCurrentMode)
end
-----------------------------------------------------------------------------------------------
-- EpiCrit OnLoad
-----------------------------------------------------------------------------------------------
function EpiCrit:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EpiCrit.xml")
	
	self.wndNewRecord = Apollo.LoadForm(self.xmlDoc, "EpiCritGranted", nil, self)
	
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
		Apollo.RegisterSlashCommand("ec", "OnEpiCritOn", self)
		Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
		-- Do additional Addon initialization here
		--tAbilities = AbilityBook.GetAbilitiesList()
		--self:BuildItemList(self.nCurrentMode)
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
-- Define general functions here

-- on SlashCommand "/ec"
function EpiCrit:OnEpiCritOn()
	self.wndMain:Invoke() -- show the window
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

-----------------------------------------------------------------------------------------------
-- EpiCrit Instance
-----------------------------------------------------------------------------------------------
local EpiCritInst = EpiCrit:new()
EpiCritInst:Init()

-----------------------------------------------------------------------------------------------
-- EpiCrit Imp
-----------------------------------------------------------------------------------------------
--Heal
function EpiCrit:OnCombatLogHeal(tEventArgs)
	self:HandleCombatLog(false, tEventArgs)
end
--Damage
function EpiCrit:OnCombatLogDamage(tEventArgs)
	self:HandleCombatLog(true, tEventArgs)
end

function EpiCrit:HandleCombatLog(bIsDamage, tEventArgs)

if not tEventArgs.unitCaster then
	return
end

if not tEventArgs.unitTarget then
	return
end

local sSpellName = tEventArgs.splCallingSpell:GetName()
local sTargetName = tEventArgs.unitTarget:GetName()
local nDamage = nil
local sCaster = tEventArgs.unitCaster:GetName()

if(sCaster == sPlayerName) then

local wndDetails = self.wndMain:FindChild("ExtInfoPopout")

if (not tEventArgs.unitCaster:IsPvpFlagged() and not tAppData.tUserPrefs.bStickyRecords and wndDetails:IsVisible()) then
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

if bIsDamage then
	nDamage = tEventArgs.nDamageAmount or 0
else
	nDamage = tEventArgs.nHealAmount or 0
end

local nTargetLevel = tEventArgs.unitTarget:GetLevel()

tDamage.sSpellName = sSpellName

local bIsCritical = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical

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
	if bIsDamage then
		bFirstRecord = tAppData.tDamageData[sSpellName] == nil
		if bFirstRecord then
			tAppData.tDamageData[sSpellName] = tDamage
			oEcDamage = tAppData.tDamageData[sSpellName]
		else
			oEcDamage = tAppData.tDamageData[sSpellName]
		end
	else
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
	--local bRefresh = false
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
	
	if wndDetails:IsVisible() then
		self:BuildOrUpdateDetailsPanel(oEcDamage, wndDetails)
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
	if not tAppData.tUserPrefs.bDisplayNotification then
		return
	end
	
	local wndRecordLabel = self.wndNewRecord:FindChild("NewRecordDialog")
	local recordText = nil
	
	if bIsCritical then
		recordText = string.format("%s with %s critical damage", oEcDamage.sSpellName, oEcDamage.tCrit.nSpellDamage)
	else
		recordText = string.format("%s with %s normal damage", oEcDamage.sSpellName, oEcDamage.tNorm.nSpellDamage)
	end
	
	wndRecordLabel:SetText(recordText)
	
	self.wndNewRecord:Show(true, true)
	self.atNewRecord:Start()
end

function EpiCrit:DestroyItemList()
	-- destroy all the wnd inside the list
	for k,v in pairs(self.tItems) do
		v:Destroy()
	end
	-- clear the list item array
	self.tItems = {}
end

function EpiCrit:BuildItemList(nMode)

self:DestroyItemList()

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


function EpiCrit:GenerateListItem(key, tData)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "EpiCritListItem", self.wndItemList, self)
	wnd:SetAnchorPoints(0,0,1,0)
	wnd:SetAnchorOffsets(0,0,0,67)
	-- keep track of the window item created
	self.tItems[key] = wnd

	-- give it a piece of data to refer to 
	local wndSkillName = wnd:FindChild("SkillName")
	local wndNmlDmgVal = wnd:FindChild("NormalDmgValue")
	local wndNmlDmgTar = wnd:FindChild("NormalDmgTarget")
	local wndCritDmgVal = wnd:FindChild("CritDmgValue")
	local wndCritDmgTar = wnd:FindChild("CritDmgTarget")
	local btnDetails = wnd:FindChild("DetailsButton")
	
	local nSkillId = 0
	
	--if not tAbilities then
		tAbilities = AbilityBook.GetAbilitiesList()
	--end
		
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
 
function EpiCrit:OnRestore(eType, tSavedData)
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    for k,v in pairs(tSavedData) do
      tAppData[k] = v
    end
  end
end

function EpiCrit:BuildOrUpdateDetailsPanel(tData, wndDetails)
	local extTitle = wndDetails:FindChild("Title")
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
--Button Handlers
function EpiCrit:ShowRecordDetails( wndHandler, wndControl, eMouseButton )
	local wndPrefs = self.wndMain:FindChild("SettingsPopout")
	
	if(wndPrefs:IsVisible()) then
		wndPrefs:Show(false, true)
	end
	
	local key = wndControl:GetContentType()
	local tData = {}
	
	if(self.nCurrentMode == 0) then
		tData = tAppData.tDamageData[key]
	elseif(self.nCurrentMode == 1) then
		tData = tAppData.tHealingData[key]
	end
	
	local wndDetails = self.wndMain:FindChild("ExtInfoPopout")
	local extTitle = wndDetails:FindChild("Title")

	self:BuildOrUpdateDetailsPanel(tData, wndDetails)
	
	if(not wndDetails:IsVisible()) then
		wndDetails:Show(true, true)
		--wndDetails:ToFront()
		elseif(extTitle:GetText() == key) then
		wndDetails:Show(false, true)
	end
		
end
function EpiCrit:ShowHealing( wndHandler, wndControl, eMouseButton )
	self.nCurrentMode = 1
	self:BuildItemList(self.nCurrentMode)
end

function EpiCrit:ShowDamage( wndHandler, wndControl, eMouseButton )
	self.nCurrentMode = 0
	self:BuildItemList(self.nCurrentMode)
end

function EpiCrit:Reset( wndHandler, wndControl, eMouseButton )
	tAppData.tDamageData = {}
	tAppData.tHealingData = {}
	self:BuildItemList(tAppData.tUserPrefs.nDefaultMode)
end

function EpiCrit:ToggleConfigurationPanel( wndHandler, wndControl, eMouseButton )

	local wndDetails = self.wndMain:FindChild("ExtInfoPopout")
	
	if(wndDetails:IsVisible()) then
		wndDetails:Show(false, true)
	end
	
	local wndPrefs = self.wndMain:FindChild("SettingsPopout")
	
	local chkDisplayNotif = wndPrefs:FindChild("ChkDisplayNotif")
	chkDisplayNotif:SetCheck(tAppData.tUserPrefs.bDisplayNotification)
	
	local chkWinDisplay = wndPrefs:FindChild("ChkWindowDisplay")
	chkWinDisplay:SetCheck(tAppData.tUserPrefs.bDisplayWindow)
	
	local chkStickyRecords = wndPrefs:FindChild("ChkStickyRecords")
	chkStickyRecords:SetCheck(tAppData.tUserPrefs.bStickyRecords)
	
	local strAddonInfoText = string.format("EpiCrit Version: %s", strAddonVersion)
	local wndVersion = wndPrefs:FindChild("AddonInfo")
	wndVersion:SetText(strAddonInfoText)
	
	local wndExc = wndPrefs:FindChild("DoNotTrackList")
	tAbilities = AbilityBook.GetAbilitiesList()
	
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
	
	wndPrefs:Show(not wndPrefs:IsVisible(), true)
	wndPrefs:ToFront()
	
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
