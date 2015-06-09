function StatusColor_SetColor(bar, unit)
	if UnitIsPlayer(unit) and unit ~= "player" and UnitIsConnected(unit) and unit == bar.unit and UnitClass(unit) then
		local c = RAID_CLASS_COLORS[select(2, UnitClass(unit))]
		bar:SetStatusBarColor(c.r, c.g, c.b)
	end
end

hooksecurefunc("UnitFrameHealthBar_Update", StatusColor_SetColor)
hooksecurefunc("HealthBar_OnValueChanged", function(self) StatusColor_SetColor(self, self.unit) end)