local Timer = {};

local UIParent = _G['UIParent']
local GetTime = _G['GetTime']

local round = function(x) return math.floor(x + 0.5) end

local ICON_SIZE = 36
local DAY, HOUR, MINUTE = 86400, 3600, 60
local DAYISH, HOURISH, MINUTEISH = 3600 * 23.5, 60 * 59.5, 59.5
local HALFDAYISH, HALFHOURISH, HALFMINUTEISH = DAY / 2 + 0.5, HOUR / 2 + 0.5, MINUTE / 2 + 0.5

local FONT_FACE = STANDARD_TEXT_FONT
local FONT_SIZE = 18
local MIN_SCALE = 0.6
local MIN_DURATION = 3
local EXPIRING_DURATION = 5
local EXPIRING_FORMAT = '|cffff0000%d|r'
local SECONDS_FORMAT = '|cffffff00%d|r'
local MINUTES_FORMAT = '|cffffffff%dm|r'
local HOURS_FORMAT = '|cff66ffff%dh|r'
local DAYS_FORMAT = '|cff6666ff%dh|r'

local function getTimeText(s)
	if s < MINUTEISH then
		local seconds = round(s)
		local formatString = seconds > EXPIRING_DURATION and SECONDS_FORMAT or EXPIRING_FORMAT
		return formatString, seconds, s - (seconds - 0.51)
	elseif s < HOURISH then
		local minutes = round(s / MINUTE)
		return MINUTES_FORMAT, minutes, minutes > 1 and (s - (minutes * MINUTE - HALFMINUTEISH)) or (s - MINUTEISH)
	elseif s < DAYISH then
		local hours = round(s / HOUR)
		return HOURS_FORMAT, hours, hours > 1 and (s - (hours * HOUR - HALFHOURISH)) or (s - HOURISH)
	else
		local days = round(s / DAY)
		return DAYS_FORMAT, days, days > 1 and (s - (days * DAY - HALFDAYISH)) or (s - DAYISH)
	end
end

function Timer.SetNextUpdate(self, nextUpdate)
	self.updater:GetAnimations():SetDuration(nextUpdate)
	if self.updater:IsPlaying() then
		self.updater:Stop()
	end
	self.updater:Play()
end

function Timer.Stop(self)
	self.enabled = nil
	if self.updater:IsPlaying() then
		self.updater:Stop()
	end
	self:Hide()
end

function Timer.UpdateText(self)
	local remain = self.duration - (GetTime() - self.start)
	if round(remain) > 0 then
		if (self.fontScale * self:GetEffectiveScale() / UIParent:GetScale()) < MIN_SCALE then
			self.text:SetText('')
			Timer.SetNextUpdate(self, 1)
		else
			local formatStr, time, nextUpdate = getTimeText(remain)
			self.text:SetFormattedText(formatStr, time)
			Timer.SetNextUpdate(self, nextUpdate)
		end
	else
		Timer.Stop(self)
	end
end

function Timer.ForceUpdate(self)
	Timer.UpdateText(self)
	self:Show()
end

function Timer.OnSizeChanged(self, width, height)
	local fontScale = round(width) / ICON_SIZE
	if fontScale == self.fontScale then
		return
	end

	self.fontScale = fontScale
	if fontScale < MIN_SCALE then
		self:Hide()
	else
		self.text:SetFont(FONT_FACE, fontScale * FONT_SIZE, 'OUTLINE')
		self.text:SetShadowColor(0, 0, 0, 0.8)
		self.text:SetShadowOffset(1, -1)
		if self.enabled then
			Timer.ForceUpdate(self)
		end
	end
end

function Timer.Create(cd)
	local scaler = CreateFrame('Frame', nil, cd)
	scaler:SetAllPoints(cd)

	local timer = CreateFrame('Frame', nil, scaler); timer:Hide()
	timer:SetAllPoints(scaler)
	
	local updater = timer:CreateAnimationGroup()
	updater:SetLooping('NONE')
	updater:SetScript('OnFinished', function(self) Timer.UpdateText(timer) end)
	
	local a = updater:CreateAnimation('Animation'); a:SetOrder(1)
	timer.updater = updater	

	local text = timer:CreateFontString(nil, 'OVERLAY')
	text:SetPoint('CENTER', 0, 0)
	text:SetFont(FONT_FACE, FONT_SIZE, 'OUTLINE')
	timer.text = text

	Timer.OnSizeChanged(timer, scaler:GetSize())
	scaler:SetScript('OnSizeChanged', function(self, ...) Timer.OnSizeChanged(timer, ...) end)

	cd.timer = timer
	return timer
end

function Timer.Start(cd, start, duration, charges, maxCharges)
	local remainingCharges = charges or 0
	if start > 0 and duration > MIN_DURATION and remainingCharges == 0 and (not cd.noCooldownCount) then
		local timer = cd.timer or Timer.Create(cd)
		timer.start = start
		timer.duration = duration
		timer.enabled = true
		Timer.UpdateText(timer)
		if timer.fontScale >= MIN_SCALE then timer:Show() end
	else
		local timer = cd.timer
		if timer then
			Timer.Stop(timer)
		end
	end
end

hooksecurefunc(getmetatable(_G['ActionButton1Cooldown']).__index, 'SetCooldown', Timer.Start)

local ActionBarButtonEventsFrame = _G['ActionBarButtonEventsFrame']
if not ActionBarButtonEventsFrame then return end

local active = {}

local function cooldown_OnShow(self)
	active[self] = true
end

local function cooldown_OnHide(self)
	active[self] = nil
end

local function cooldown_ShouldUpdateTimer(self, start, duration, charges, maxCharges)
	local timer = self.timer
	if not timer then
		return true
	end
	return not(timer.start == start or timer.charges == charges or timer.maxCharges == maxCharges)
end

local function cooldown_Update(self)
	local button = self:GetParent()
	local action = button.action
	
	local start, duration, enable = GetActionCooldown(action)
	local charges, maxCharges, chargeStart, chargeDuration = GetActionCharges(action)
	
	if cooldown_ShouldUpdateTimer(self, start, duration, charges, maxCharges) then
		Timer.Start(self, start, duration, charges, maxCharges)
	end
end

local abEventWatcher = CreateFrame('Frame'); abEventWatcher:Hide()
abEventWatcher:SetScript('OnEvent', function(self, event)
	for cooldown in pairs(active) do
		cooldown_Update(cooldown)
	end
end)
abEventWatcher:RegisterEvent('ACTIONBAR_UPDATE_COOLDOWN')

local hooked = {}

local function actionButton_Register(frame)
	local cooldown = frame.cooldown
	if not hooked[cooldown] then
		cooldown:HookScript('OnShow', cooldown_OnShow)
		cooldown:HookScript('OnHide', cooldown_OnHide)
		hooked[cooldown] = true
	end
end

if ActionBarButtonEventsFrame.frames then
	for i, frame in pairs(ActionBarButtonEventsFrame.frames) do
		actionButton_Register(frame)
	end
end

hooksecurefunc('ActionBarButtonEventsFrame_RegisterFrame', actionButton_Register)