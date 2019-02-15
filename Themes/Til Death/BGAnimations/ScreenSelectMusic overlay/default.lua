local showVisualizer = themeConfig:get_data().global.ShowVisualizer

local function input(event)
	if event.DeviceInput.button == "DeviceButton_left mouse button" and event.type == "InputEventType_Release" then
		MESSAGEMAN:Broadcast("MouseLeftClick")
	elseif event.DeviceInput.button == "DeviceButton_right mouse button" and event.type == "InputEventType_Release" then
		MESSAGEMAN:Broadcast("MouseRightClick")
	end
	return false
end

local t =
	Def.ActorFrame {
	BeginCommand = function(self)
		local s = SCREENMAN:GetTopScreen()
		s:AddInputCallback(input)
	end
}

t[#t + 1] =
	Def.Actor {
	CodeMessageCommand = function(self, params)
		if params.Name == "AvatarShow" and getTabIndex() == 0 and not SCREENMAN:get_input_redirected(PLAYER_1) then
			SCREENMAN:AddNewScreenToTop("ScreenAvatarSwitch")
		end
	end
}

t[#t + 1] = LoadActor("../_frame")
t[#t + 1] = LoadActor("../_PlayerInfo")

if showVisualizer then
	local vis =
		audioVisualizer:new {
		x = 175,
		y = 30,
		maxHeight = 30,
		freqIntervals = audioVisualizer.multiplyIntervals(audioVisualizer.defaultIntervals, 5),
		color = getMainColor("positive"),
		onBarUpdate = function(self)
			--[
			self:diffusetopedge(getMainColor("frames"))
			self:diffusebottomedge(getMainColor("positive"))
			--]]
			--[[
			self:diffuselowerleft()
			self:diffuseupperleft()
			self:diffuselowerright()
			self:diffuseupperright()
			--]]
		end
	}
	t[#t + 1] = vis
end


t[#t + 1] = LoadActor("currentsort")
t[#t + 1] =
	LoadFont("Common Large") ..
	{
		InitCommand = function(self)
			self:xy(5, 32):halign(0):valign(1):zoom(0.55):diffuse(getMainColor("positive")):settext("Select Music:")
		end
	}

t[#t + 1] = LoadActor("../_cursor")
t[#t + 1] = LoadActor("../_halppls")
t[#t + 1] = LoadActor("currenttime")

GAMESTATE:UpdateDiscordMenu(
	GetPlayerOrMachineProfile(PLAYER_1):GetDisplayName() ..
		": " .. string.format("%5.2f", GetPlayerOrMachineProfile(PLAYER_1):GetPlayerRating())
)

return t