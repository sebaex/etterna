local t = Def.ActorFrame {}

local timeFontActor
t[#t + 1] =
	LoadFont("Common Normal") ..
	{
		Name = "currentTime",
		InitCommand = function(self)
			timeFontActor = self
			self:xy(SCREEN_WIDTH - 5, SCREEN_BOTTOM - 5):halign(1):valign(1):zoom(0.45)
		end
	}

local function Update(self)
	local year = Year()
	local month = MonthOfYear() + 1
	local day = DayOfMonth()
	local hour = Hour()
	local minute = Minute()
	local second = Second()
	timeFontActor:settextf("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
end

t.InitCommand = function(self)
	self:diffuse(getMainColor("positive"))
	self:SetUpdateFunction(Update)
	self:SetUpdateFunctionInterval(1)
end

return t
