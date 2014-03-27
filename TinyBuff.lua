TinyBuff_Config = TinyBuff_Config or { PlayerBuffsCount = 10, PlayerBuffs = {}, TargetBuffs = {}, TargetDebuffs = {} }
local ICON_SIZE = 30

local Addon = CreateFrame("Frame")
local PlayerName = UnitName("player")
local PlayerBuffs = {}

local function Find(array, filterFunc)
	for _, v in pairs(array) do
  		if filterFunc(v) then
  			return v
  		end
	end
end

local function Contains(array, value)
	return Find(array, function(x) return x == value end)
end

local function FindBySpell(array, spell)
	return Find(array, function(x) return x.Spell == spell end)
end

local function NewIcon(point, size)
	local icon = CreateFrame("Frame")
	icon:Hide()

	icon:SetSize(size, size)
	icon:SetPoint(unpack(point))
	icon:SetAlpha(0.7)

	icon.Overlay = icon:CreateTexture("Overlay", "BACKGROUND")
	icon.Overlay:SetTexture(0, 0, 0)
	icon.Overlay:SetPoint("TOPLEFT", -1, 1)
	icon.Overlay:SetPoint("BOTTOMRIGHT", 1, -1)

	icon.Image = icon:CreateTexture("Image", "OVERLAY")
	icon.Image:SetAllPoints()
	icon.Image:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	icon.Cooldown = CreateFrame("Cooldown", "Cooldown", icon, "CooldownFrameTemplate")
	icon.Cooldown:SetAllPoints(icon.Image)
	icon.Cooldown:SetReverse()

	function icon:Enable(spell, icon, duration, expiration)
		self.Image:SetTexture(icon)
		self.Spell = spell

		if duration then
			self.Cooldown:Show()
			self:SetCooldown(duration, expiration)
		else
			self.Cooldown:Hide()
		end

		self:Show()
	end

	function icon:SetCooldown(duration, expiration)
		CooldownFrame_SetTimer(self.Cooldown, expiration - duration, duration, 1)
	end

	function icon:Disable()
		self.Spell = nil
		self:Hide()
	end

	return icon
end

local function CreatePlayerBuffs()
	for i = 1, TinyBuff_Config.PlayerBuffsCount do
		local x = -9 - ((i - 1) % 2) * (ICON_SIZE + 3)
		local y = -10 + math.floor((i - 1) / 2) * (ICON_SIZE + 3)
		PlayerBuffs[i] = NewIcon({ "BOTTOMRIGHT", "PlayerFrame", "TOPRIGHT", x, y }, ICON_SIZE)
	end
end

local function HandlePlayerBuff(combatEvent, _, spell)
	if Contains(TinyBuff_Config.PlayerBuffs, spell) == nil then
		return
	end
	if string.find(combatEvent, "REFRESH") or string.find(combatEvent, "DOSE") then
		local buff = FindBySpell(PlayerBuffs, spell)
		if buff then
			local _, _, _, _, _, duration, expiration = UnitAura("player", spell)
			buff:SetCooldown(duration, expiration)
		end
	elseif string.find(combatEvent, "APPLIED") then
		local buff = FindBySpell(PlayerBuffs, nil)
		if buff then
			local _, _, icon, _, _, duration, expiration = UnitAura("player", spell)
			buff:Enable(spell, icon, duration, expiration)
		end
	else
		local buff = FindBySpell(PlayerBuffs, spell)
		if buff then
			buff:Disable()
		end
	end
end

local function OnEvent(self, event, _, combatEvent, _, _, _, sourceFlags, _, _, destName, _, _, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if destName == PlayerName and bit.band(sourceFlags, 0x3) and string.find(combatEvent, "AURA") then
			HandlePlayerBuff(combatEvent, ...)
		end
	end
end

CreatePlayerBuffs()

Addon:SetScript("OnEvent", OnEvent)
Addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Addon:RegisterEvent("PLAYER_TARGET_CHANGED")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")