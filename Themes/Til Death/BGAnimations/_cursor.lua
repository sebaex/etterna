--file containing stuff for cursors.
--this should only be loaded by screen overlays,
--otherwise the inputcallback function won't be able to find the actors.

local maxChild = 20
local curIndex = 0

function cursorClick(index)
	return LoadActor(THEME:GetPathG("", "_circle")) ..
		{
			Name = "CursorClick",
			InitCommand = function(self)
				self:diffusealpha(0)
			end,
			MouseLeftClickMessageCommand = function(self)
				if index == curIndex then
					self:finishtweening()
					self:xy(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
					self:diffusealpha(1)
					self:zoom(0)
					self:decelerate(0.5)
					self:diffusealpha(0)
					self:zoom(1)
				end
			end
		}
end

local t =
	Def.ActorFrame {
	Name = "Cursor"
}

for i = 0, maxChild do
	t[#t + 1] = cursorClick(i)
end

t[#t + 1] =
	Def.Quad {
	Name = "Cursor",
	InitCommand = function(self)
		self:xy(0, 0):zoomto(4, 4):rotationz(45)
	end
}
local IsWindowed
do
	local getpref = PREFSMAN.GetPreference
	IsWindowed = function()
		getpref(PREFSMAN, "Windowed")
	end
end
local cursorActor
local lastUpdateWindowedStatus = false
-- Update less often if not windowed
local updateIntervalInvisible = 5
local updateIntervalVisible = 1/20
local function Update(self)
	--self:GetChild("MouseXY"):settextf("X:%5.2f Y:%5.2f W:%5.2f",INPUTFILTER:GetMouseX(),INPUTFILTER:GetMouseY(),INPUTFILTER:GetMouseWheel())
	local isWindowed = IsWindowed()
	if lastUpdateWindowedStatus ~= isWindowed then
		lastUpdateWindowedStatus = isWindowed
		if not isWindowed then
			self:SetUpdateFunctionInterval(updateIntervalVisible)
			cursorActor:visible(true)
		else
			self:SetUpdateFunctionInterval(updateIntervalInvisible)
			cursorActor:visible(false)
		end
	end
	cursorActor:xy(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()):visible()
	--self:GetChild("FullScreen"):settextf("FullScreen: %s",tostring(not PREFSMAN:GetPreference("Windowed")))
end
t.BeginCommand = function(self)
	cursorActor = self:GetChild("Cursor")
	self:SetUpdateFunction(Update)
	self:SetUpdateFunctionInterval(updateIntervalVisible)
end

return t
