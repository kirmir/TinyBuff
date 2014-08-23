TinyBuff_Config = TinyBuff_Config or { PlayerBuffsCount = 8, TargetBuffsCount = 8, TargetDebuffsCount = 12, PlayerBuffs = {}, TargetBuffs = {}, TargetDebuffs = {} }
local ICON_SIZE = 30

local Addon = CreateFrame("Frame")
local PlayerGuid
local PlayerBuffs = {}
local TargetBuffs = {}
local TargetDebuffs = {}

local function Find(array, filterFunc)
	for _, v in pairs(array) do
  		if filterFunc(v) then
  			return v
  		end
	end
end

local function ContainsSpell(array, spellName, spellId)
	return Find(array, function(x)
		return x == (spellName..spellId) or x == spellName
	end)
end

local function FindByParams(array, spellId, guid)
	return Find(array, function(x)
		return x.SpellId == spellId and x.DestGuid == guid
	end)
end

local function NewIcon(point, size)
	local icon = CreateFrame("Frame")
	icon:Hide()

	icon:SetSize(size, size)
	icon:SetPoint(unpack(point))

	icon.Image = icon:CreateTexture("Image", "OVERLAY")
	icon.Image:SetAllPoints()
	icon.Image:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon.Image:SetAlpha(0.7)

	icon.Cooldown = CreateFrame("Cooldown", "Cooldown", icon, "CooldownFrameTemplate")
	icon.Cooldown:SetAllPoints(icon.Image)
	icon.Cooldown:SetReverse()

	function icon:Enable(spellId, destGuid, sourceGuid, icon, duration, expiration)
		self.Image:SetTexture(icon)
		self.SpellId = spellId
		self.DestGuid = destGuid
		self.SourceGuid = sourceGuid

		if duration > 0 then
			self.Expiration = expiration
			self.Cooldown:Show()
			CooldownFrame_SetTimer(self.Cooldown, expiration - duration, duration, 1)

			self:SetScript("OnUpdate", function(self)
				if GetTime() > self.Expiration then
					self:Disable()
				end
			end)
		else
			self.Cooldown:Hide()
		end

		self:Show()
	end

	function icon:Disable()
		self.SpellId = nil
		self.DestGuid = nil
		self.SourceGuid = nil
		self.Expiration = nil
		self:SetScript("OnUpdate", nil)
		self:Hide()
	end

	return icon
end

local function CreateIcons()
	if #TinyBuff_Config.PlayerBuffs > 0 then
		for i = 1, TinyBuff_Config.PlayerBuffsCount do
			local x = -140 - ((i - 1) % 2) * (ICON_SIZE + 4)
			local y = -138 + math.floor((i - 1) / 2) * (ICON_SIZE + 4)
			PlayerBuffs[i] = NewIcon({ "CENTER", "UIParent", "CENTER", x, y }, ICON_SIZE)
		end
	end
	if #TinyBuff_Config.TargetBuffs > 0 then
		for i = 1, TinyBuff_Config.TargetBuffsCount do
			local x = ((i % 2 == 1) and 1 or -1) * (17 - math.ceil((math.floor((i - 1) % 6) + 1) / 2) * (ICON_SIZE + 4))
			local y = 109 + math.floor((i - 1) / 6) * (ICON_SIZE + 4)
			TargetBuffs[i] = NewIcon({ "CENTER", "UIParent", "CENTER", x, y }, ICON_SIZE)
		end
	end
	if #TinyBuff_Config.TargetDebuffs > 0 then
		for i = 1, TinyBuff_Config.TargetDebuffsCount do
			local x = ((i % 2 == 1) and 1 or -1) * (17 - math.ceil((math.floor((i - 1) % 6) + 1) / 2) * (ICON_SIZE + 4))
			local y = -183 + math.floor((i - 1) / 6) * (ICON_SIZE + 4)
			TargetDebuffs[i] = NewIcon({ "CENTER", "UIParent", "CENTER", x, y }, ICON_SIZE)
		end
	end
end

local function GetUnitType(guid)
	if guid == PlayerGuid then
		return "player"
	end
	if guid == UnitGUID("target") then
		return "target"
	end
	if guid == UnitGUID("focus") then
		return "focus"
	end
end

local function EnableIcon(spellId, destGuid, sourceGuid, img, duration, expiration, icons)
	local icon = FindByParams(icons, spellId, destGuid) or FindByParams(icons, nil, nil)
	if icon then
		icon:Enable(spellId, destGuid, sourceGuid, img, duration, expiration)
	end
end

local function OnAuraEvent(event, spellId, spellName, destGuid, sourceGuid, icons, config, auraFunc)
	if not ContainsSpell(config, spellName, spellId) then
		return
	end

	if string.match(event, "REMOVED$") then
		local icon = FindByParams(icons, spellId, destGuid)
		if icon and icon.SourceGuid == sourceGuid then
			icon:Disable()
		end
	else
		local unit = GetUnitType(destGuid)
		if unit then
			for i = 1, 40 do
				local _, _, img, _, _, duration, expiration, _, _, _, id = auraFunc(unit, i)
				if id == spellId then
					EnableIcon(id, destGuid, sourceGuid, img, duration, expiration, icons)
					break
				end
			end
		end
	end
end

local function ShowSpell(i, destGuid, sourceGuid, icons, config, auraFunc)
	local spellName, _, img, _, _, duration, expiration, _, _, _, spellId = auraFunc("target", i)
	if spellName and ContainsSpell(config, spellName, spellId) then
		EnableIcon(spellId, destGuid, sourceGuid, img, duration, expiration, icons)
	end
end

local function Reset(icons, guid)
	for _, v in pairs(icons) do
	  	if not guid or v.DestGuid == guid then
	  		v:Disable()
	  	end
	end
end

local function OnEvent(self, event, addon, combatEvent, _, sourceGuid, _, _, _, destGuid, _, destFlags, _, spellId, spellName, _, spellType)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if combatEvent == "UNIT_DIED" then
			Reset(TargetBuffs, destGuid)
			Reset(TargetDebuffs, destGuid)
			return
		end

		if not string.find(combatEvent, "AURA") then
			return
		end
		
		if destGuid == PlayerGuid and spellType == "BUFF" then
			OnAuraEvent(combatEvent, spellId, spellName, destGuid, sourceGuid, PlayerBuffs, TinyBuff_Config.PlayerBuffs, UnitBuff)
		elseif bit.band(destFlags, 0x60) ~= 0 then
			if spellType == "BUFF" then
				OnAuraEvent(combatEvent, spellId, spellName, destGuid, sourceGuid, TargetBuffs, TinyBuff_Config.TargetBuffs, UnitBuff)
			else
				OnAuraEvent(combatEvent, spellId, spellName, destGuid, sourceGuid, TargetDebuffs, TinyBuff_Config.TargetDebuffs, UnitDebuff)
			end
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		local guid = UnitGUID("target")
		for i = 1, 40 do
			ShowSpell(i, guid, sourceGuid, TargetDebuffs, TinyBuff_Config.TargetDebuffs, UnitDebuff)
			ShowSpell(i, guid, sourceGuid, TargetBuffs, TinyBuff_Config.TargetBuffs, UnitBuff)
		end
	elseif event == "PLAYER_DEAD" then
		Reset(PlayerBuffs)
	elseif event == "PLAYER_ENTERING_WORLD" then
		Reset(PlayerBuffs)
		Reset(TargetBuffs)
		Reset(TargetDebuffs)
	else
		PlayerGuid = UnitGUID("player")
		if PlayerGuid then
			Addon:UnregisterEvent("ADDON_LOADED")
		end
		CreateIcons()
	end
end

Addon:SetScript("OnEvent", OnEvent)
Addon:RegisterEvent("ADDON_LOADED")
Addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Addon:RegisterEvent("PLAYER_DEAD")
Addon:RegisterEvent("PLAYER_TARGET_CHANGED")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")