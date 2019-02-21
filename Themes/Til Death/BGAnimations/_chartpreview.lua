-- all the preview stuff should be var'd and used consistently -mina
local noteField = false
local prevZoom = 0.65
local musicratio = 1

-- hurrrrr nps quadzapalooza -mina
local wodth = capWideScale(280, 300)
local hidth = 40
local yeet
local cd
local topScreen
local PosActor

local function UpdatePreviewPos(self)
	if
		noteField and yeet and topScreen:GetName() == "ScreenSelectMusic" or
			noteField and yeet and topScreen:GetName() == "ScreenNetSelectMusic"
	 then
		local pos = topScreen:GetPreviewNoteFieldMusicPosition() / musicratio
		PosActor:zoomto(math.min(pos, wodth), hidth)
		self:queuecommand("Highlight")
	end
end

local memehamstermax
local function setUpPreviewNoteField()
	yeet = topScreen:CreatePreviewNoteField()
	if yeet == nil then
		return
	end
	yeet:zoom(prevZoom):draworder(90)
	topScreen:dootforkfive(memehamstermax)
	yeet = memehamstermax:GetChild("NoteField")
	yeet:x(wodth / 2)
	memehamstermax:SortByDrawOrder()
	MESSAGEMAN:Broadcast("NoteFieldVisible")
end

local getMousePosition = getMousePosition
local frameActor
local SeekActor
local SeekTextActor

local t =
	Def.ActorFrame {
	Name = "ChartPreview",
	InitCommand = function(self)
		frameActor = self
		self:visible(false)
		self:SetUpdateFunctionInterval(1 / 35)
		cd = self:GetChild("ChordDensityGraph"):visible(false):draworder(1000)
		memehamstermax = self
	end,
	BeginCommand = function()
		topScreen = SCREENMAN:GetTopScreen()
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:GetChild("pausetext"):settext("")
		if GAMESTATE:GetCurrentSong() then
			musicratio = GAMESTATE:GetCurrentSong():GetLastSecond() / wodth
		end
	end,
	MouseRightClickMessageCommand = function(self)
		SCREENMAN:GetTopScreen():PausePreviewNoteField()
		if SCREENMAN:GetTopScreen():IsPreviewNoteFieldPaused() then
			self:GetChild("pausetext"):settext("Paused")
		else
			self:GetChild("pausetext"):settext("")
		end
	end,
	SetupNoteFieldCommand = function(self)
		self:SetUpdateFunction(UpdatePreviewPos)
		setUpPreviewNoteField()
		noteField = true
	end,
	hELPidontDNOKNOWMessageCommand = function(self)
		self:SetUpdateFunction(nil)
		SCREENMAN:GetTopScreen():DeletePreviewNoteField(self)
	end,
	NoteFieldVisibleMessageCommand = function(self)
		self:SetUpdateFunction(UpdatePreviewPos)
		self:visible(true)
		cd:visible(true):y(20) -- need to control this manually -mina
		cd:GetChild("cdbg"):diffusealpha(0) -- we want to use our position background for draw order stuff -mina
		cd:queuecommand("GraphUpdate") -- first graph will be empty if we dont force this on initial creation
	end,
	Def.Quad {
		Name = "BG",
		InitCommand = function(self)
			self:xy(wodth / 2, SCREEN_HEIGHT / 2)
			self:diffuse(color("0.05,0.05,0.05,1"))
		end,
		CurrentStyleChangedMessageCommand = function(self)
			local cols = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
			self:zoomto(48 * cols, SCREEN_HEIGHT)
		end
	},
	LoadFont("Common Normal") ..
		{
			Name = "pausetext",
			InitCommand = function(self)
				self:xy(wodth / 2, SCREEN_HEIGHT / 2)
				self:settext(""):diffuse(color("0.8,0,0"))
			end
		},
	Def.Quad {
		Name = "PosBG",
		InitCommand = function(self)
			self:zoomto(wodth, hidth):halign(0):diffuse(color("1,1,1,1")):draworder(900)
		end,
		HighlightCommand = function(self) -- use the bg for detection but move the seek pointer -mina
			local mx, my = getMousePosition()
			if self:IsOver(mx, my) then
				SeekActor:visible(true)
				SeekTextActor:visible(true)
				SeekActor:x(mx - frameActor:GetX())
				SeekTextActor:x(mx - frameActor:GetX() - 4) -- todo: refactor this lmao -mina
				SeekTextActor:y(my - frameActor:GetY())
				SeekTextActor:settextf("%0.2f", SeekActor:GetX() * musicratio / getCurRateValue())
			else
				SeekTextActor:visible(false)
				SeekActor:visible(false)
			end
		end
	},
	Def.Quad {
		Name = "Pos",
		InitCommand = function(self)
			PosActor = self
			self:zoomto(0, hidth):diffuse(color("0,1,0,.5")):halign(0):draworder(900)
		end
	}
}

t[#t + 1] = LoadActor("_chorddensitygraph.lua")

-- more draw order shenanigans
t[#t + 1] =
	LoadFont("Common Normal") ..
	{
		Name = "Seektext",
		InitCommand = function(self)
			SeekTextActor = self
			self:y(8):valign(1):halign(1):draworder(1100):diffuse(color("0.8,0,0")):zoom(0.4)
		end
	}

t[#t + 1] =
	Def.Quad {
	Name = "Seek",
	InitCommand = function(self)
		SeekActor = self
		self:zoomto(2, hidth):diffuse(color("1,.2,.5,1")):halign(0.5):draworder(1100)
	end,
	MouseLeftClickMessageCommand = function(self)
		if isOver(self) then
			SCREENMAN:GetTopScreen():SetPreviewNoteFieldMusicPosition(self:GetX() * musicratio)
		end
	end
}

return t
