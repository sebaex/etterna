--[[
	It seems using this doesn't actually improve performance *at all*
	Despite (https://stackoverflow.com/questions/16131793/when-using-luajit-is-it-better-to-use-ffi-or-normal-lua-bindings)
	My guess is the call-overhead is really not a bottleneck or any significant part of cpu load
]]
local ffi = require("ffi")
local C = ffi.C
FFIUtils = {}
--[[
	Actor lua handles are tables, which allows themers to store state in self
	Because of this, there's a global table which maps the actor table to the 
	actor userdata (The pointer to the C++ object)
]]
local GlobalActorTable = GlobalActorTable
FFIUtils.GlobalActorTable = GlobalActorTable
local function getActorPtr(thing)
	--[[
		Singletons are cdatas (ptrs) already, so we only index the table if self is a table(actor)
		We need to account for this because both normal actors and singletons/screens use the metatable
	--]]
	return type(thing) == "table" and GlobalActorTable[thing] or thing
end
FFIUtils.getActorPtr = getActorPtr
local funcs = {
	[0] = function(fName)
		return function(self)
			return C[fName](getActorPtr(self))
		end
	end,
	[1] = function(fName)
		return function(self, a)
			return C[fName](getActorPtr(self), a)
		end
	end,
	[2] = function(fName)
		return function(self, a, b)
			return C[fName](getActorPtr(self), a, b)
		end
	end,
	[3] = function(fName)
		return function(self, a, b, c)
			return C[fName](getActorPtr(self), a, b, c)
		end
	end,
	[4] = function(fName)
		return function(self, a, b, c, d)
			return C[fName](getActorPtr(self), a, b, c, d)
		end
	end,
	[5] = function(fName)
		return function(self, a, b, c, d, e)
			return C[fName](getActorPtr(self), a, b, c, d, e)
		end
	end
}
local function generator(fName, n, dontReturnSelf)
	local f = funcs[n](fName)
	return dontReturnSelf and f or function(self, ...)
			f(self, ...)
			return self
		end
end
FFIUtils.generator = generator

ffi.cdef [[
	float InputFilterGetMouseX();
	float InputFilterGetMouseY();
	float InputFilterGetMouseY();
	bool InputFilterIsBeingPressed(const char* b, const char* optDevice);
	float InputFilterIsShiftPressed();
	float InputFilterIsControlPressed();
]]
InputFilter.GetMouseX = function()
	return C.InputFilterGetMouseX()
end
InputFilter.GetMouseY = function()
	return C.InputFilterGetMouseY()
end
InputFilter.IsShiftPressed = function()
	return C.InputFilterIsShiftPressed()
end
InputFilter.IsControlPressed = function()
	return C.InputFilterIsControlPressed()
end
InputFilter.IsBeingPressed = function(button, device)
	return C.InputFilterIsBeingPressed(button, device)
end

ffi.cdef [[
	void ActorSetX(void* a, float x);
	void ActorSetY(void* a, float x);
	void ActorSetName(void* a, const char* x);
	void ActorLinear(void* a, float x);
	void ActorAccelerate(void* a, float x);
	void ActorDecelerate(void* a, float x);
	void ActorSpring(void* a, float x);
	void ActorStopTweening(void* a);
	void ActorFinishTweening(void* a);
	void ActorHurryTweening(void* a, float x);
	void ActorSleep(void* a, float x);
	void ActorSetZ(void* a, float x);
	void ActorSetXY(void* a, float x, float y);
	void ActorAddX(void* a, float x);
	void ActorAddY(void* a, float x);
	void ActorAddZ(void* a, float x);
	void ActorSetZoom(void* a, float x);
	void ActorSetZoomX(void* a, float x);
	void ActorSetZoomY(void* a, float x);
	void ActorSetZoomZ(void* a, float x);
	void ActorSetZoomTo(void* a, float x, float y);
	void ActorZoomToWidth(void* a, float x);
	void ActorZoomToHeight(void* a, float x);
	void ActorSetWidth(void* a, float x);
	void ActorSetHeight(void* a, float x);
	void ActorSetSize(void* a, float x, float y);
	void ActorSetBaseAlpha(void* a, float x);
	void ActorSetBaseZoom(void* a, float x);
	void ActorSetBaseZoomX(void* a, float x);
	void ActorSetBaseZoomY(void* a, float x);
	void ActorSetBaseZoomZ(void* a, float x);
	void ActorStretchTo(void* a, float x, float y, float z, float h);
	void ActorSetCropLeft(void* a, float x);
	void ActorSetCropTop(void* a, float x);
	void ActorSetCropRight(void* a, float x);
	void ActorSetCropBottom(void* a, float x);
	void ActorSetFadeLeft(void* a, float x);
	void ActorSetFadeTop(void* a, float x);
	void ActorSetFadeRight(void* a, float x);
	void ActorSetFadeBottom(void* a, float x);
	
	void ActorSetDiffuse(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseUpperLeft(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseUpperRight(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseLowerLeft(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseLowerRight(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseLeftEdge(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseRightEdge(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseTopEdge(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseBottomEdge(void* a, float r1, float g1, float b1, float a1);
	void ActorSetDiffuseAlpha(void* a, float c);
	void ActorSetDiffuseColor(void* a, float r1, float g1, float b1, float a1);
	void ActorSetGlow(void* a, float r1, float g1, float b1, float a1);

	void ActorSetAux(void* a, float c);
	float ActorGetAux(void* a);
	void ActorSetRotationX(void* a, float x);
	void ActorSetRotationY(void* a, float x);
	void ActorSetRotationZ(void* a, float x);
	void ActorAddRotationX(void* a, float x);
	void ActorAddRotationY(void* a, float x);
	void ActorAddRotationZ(void* a, float x);
	void ActorGetRotation(void* a, float* buffSizeThree);
	void ActorSetBaseRotationX(void* a, float x);
	void ActorSetBaseRotationY(void* a, float x);
	void ActorSetBaseRotationZ(void* a, float x);
	void ActorSetSkewX(void* a, float x);
	void ActorSetSkewY(void* a, float x);
	void ActorHeading(void* a, float x);
	void ActorPitch(void* a, float x);
	void ActorRoll(void* a, float x);
	void ActorSetShadowLength(void* a, float x);
	void ActorSetShadowLengthX(void* a, float x);
	void ActorSetShadowLengthY(void* a, float x);
	//void ActorSetShadowColor(void* a, RageColor x);
	void Actorhalign(void* a, float x);
	void Actorvalign(void* a, float x);
	void ActorSetVertAlign(void* a, float x);
	void ActorSetHorizAlign(void* a, float x);
	void Actordiffuseblink(void* a);
	void Actordiffuseshift(void* a);
	void Actordiffuseramp(void* a);
	void Actorglowblink(void* a);
	void Actorglowshift(void* a);
	void Actorglowramp(void* a);
	void Actorrainbow(void* a);
	void Actorwag(void* a);
	void Actorbounce(void* a);
	void Actorbob(void* a);
	void Actorpulse(void* a);
	void Actorspin(void* a);
	void Actorvibrate(void* a);
	void ActorStopEffect(void* a);
	//void ActorSetEffectColor1(void* a, RageColor c);
	//void ActorSetEffectColor2(void* a, RageColor c);
	void ActorSetEffectPeriod(void* a, float c);
	const char* ActorSetEffectTiming(void* a, float rth, float hah, float rtf, float haz, float haf);
	const char* ActorSetEffectHoldAtFull(void* a, float x);
	void ActorSetEffectOffset(void* a, float c);
	void ActorSetEffectClockString(void* a, const char* c);
	void ActorSetEffectMagnitude(void* a, float x, float y, float z);
	void ActorGetEffectMagnitude(void* a, float* buffSizeThree);
	void Actorset_tween_uses_effect_delta(void* a, float x);
	float Actorget_tween_uses_effect_delta(void* a);
	void ActorScaleToCover(void* a, float x, float y, float z, float h);
	void ActorScaleToFit(void* a, float x, float y, float z, float h);
	void ActorEnableAnimation(void* a, bool c);
	void ActorPlay(void* a);
	void ActorPause(void* a);
	void ActorSetTextureWrapping(void* a, bool c);
	void ActorSetState(void* a, float x);
	int ActorGetNumStates(void* a);
	void ActorSetTextureTranslate(void* a, float x, float y);
	void ActorSetTextureFiltering(void* a, bool c);
	void ActorSetUseZBuffer(void* a, bool c);
	void ActorZTest(void* a, bool c);
	void ActorSetZWrite(void* a, bool c);
	void ActorSetZBias(void* a, float c);
	void ActorSetClearZBuffer(void* a, bool c);
	void ActorBackfaceCull(void* a, bool c);
	//
	void ActorSetVisible(void* a, bool c);
	void ActorSetDrawOrder(void* a, float c);
	void ActorQueueCommand(void* a, const char* c);
	void ActorQueueMessage(void* a, const char* c);
	float ActorGetX(void* a);
	float ActorGetY(void* a);
	float ActorGetZ(void* a);
	float ActorGetDestX(void* a);
	float ActorGetDestY(void* a);
	float ActorGetDestZ(void* a);
	float ActorGetWidth(void* a);
	float ActorGetHeight(void* a);
	float ActorGetZoomedWidth(void* a);
	float ActorGetZoomedHeight(void* a);
	float ActorGetZoom(void* a);
	float ActorGetZoomX(void* a);
	float ActorGetZoomY(void* a);
	float ActorGetZoomZ(void* a);
	float ActorGetBaseZoomX(void* a);
	float ActorGetBaseZoomY(void* a);
	float ActorGetBaseZoomZ(void* a);
	float ActorGetBaseRotationX(void* a);
	float ActorGetBaseRotationY(void* a);
	float ActorGetBaseRotationZ(void* a);
	float ActorGetSecsIntoEffect(void* a);
	float ActorGetEffectDelta(void* a);
	bool ActorGetVisible(void* a);
	float ActorGetHAlign(void* a);
	float ActorGetVAlign(void* a);
	const char* ActorGetName(void* a);
	void ActorSetFakeParent(void* a, void* b);
	void ActorDraw(void* a);
	void ActorSaveXY(void* a, float x, float y);
	void ActorLoadXY(void* a);
	bool ActorIsOver(void* a, float x, float y);
	bool ActorIsVisible(void*a);
]]

Actor.x = generator("ActorSetX", 1)
Actor.y = generator("ActorSetY", 1)
Actor.z = generator("ActorSetZ", 1)
--Actor.name = generator("ActorSetName", 1)
Actor.SetX = Actor.x
Actor.SetY = Actor.y
Actor.SetZ = Actor.z
Actor.SetName = Actor.name
Actor.linear = generator("ActorLinear", 1)
Actor.accelerate = generator("ActorAccelerate", 1)
Actor.decelerate = generator("ActorDecelerate", 1)
Actor.spring = generator("ActorSpring", 1)
Actor.stoptweening = generator("ActorStopTweening", 0)
Actor.finishtweening = generator("ActorFinishTweening", 0)
Actor.hurrytweening = generator("ActorHurryTweening", 1)
Actor.Sleep = generator("ActorSleep", 1)
Actor.sleep = Actor.Sleep
Actor.SetXY = generator("ActorSetXY", 2)
Actor.xy = Actor.SetXY
Actor.AddX = generator("ActorAddX", 1)
Actor.AddY = generator("ActorAddY", 1)
Actor.AddZ = generator("ActorAddZ", 1)
Actor.addx = Actor.AddX
Actor.addy = Actor.AddY
Actor.addz = Actor.AddZ
Actor.SetZoom = generator("ActorSetZoom", 1)
Actor.SetZoomX = generator("ActorSetZoomX", 1)
Actor.SetZoomY = generator("ActorSetZoomY", 1)
Actor.SetZoomZ = generator("ActorSetZoomZ", 1)
Actor.SetZoomTo = generator("ActorSetZoomTo", 2)
--Actor.zoom = Actor.SetZoom
Actor.zoomx = Actor.SetZoomX
Actor.zoomy = Actor.SetZoomY
Actor.zoomz = Actor.SetZoomZ
Actor.zoomto = Actor.SetZoomTo
Actor.ZoomToWidth = generator("ActorZoomToWidth", 1)
Actor.ZoomToHeight = generator("ActorZoomToHeight", 1)
Actor.zoomtowidth = Actor.ZoomToWidth
Actor.zoomtoheight = Actor.ZoomToHeight
Actor.SetWidth = generator("ActorSetWidth", 1)
Actor.SetHeight = generator("ActorSetHeight", 1)
Actor.SetSize = generator("ActorSetSize", 2)
Actor.setsize = Actor.SetSize
Actor.SetBaseAlpha = generator("ActorSetBaseAlpha", 1)
Actor.SetBaseZoom = generator("ActorSetBaseZoom", 1)
Actor.SetBaseZoomX = generator("ActorSetBaseZoomX", 1)
Actor.SetBaseZoomY = generator("ActorSetBaseZoomY", 1)
Actor.SetBaseZoomZ = generator("ActorSetBaseZoomZ", 1)
Actor.StretchTo = generator("ActorStretchTo", 4)
Actor.SetCropLeft = generator("ActorSetCropLeft", 1)
Actor.SetCropTop = generator("ActorSetCropTop", 1)
Actor.SetCropRight = generator("ActorSetCropRight", 1)
Actor.SetCropBottom = generator("ActorSetCropBottom", 1)
Actor.SetFadeLeft = generator("ActorSetFadeLeft", 1)
Actor.SetFadeTop = generator("ActorSetFadeTop", 1)
Actor.SetFadeRight = generator("ActorSetFadeRight", 1)
Actor.SetFadeBottom = generator("ActorSetFadeBottom", 1)
Actor.SetFadeBottom = generator("ActorSetFadeBottom", 1)

--[[
local function setColorGenerator(stfNamer)
	return function(self, r, g, b, a)
		if type(r) == "table" then
			C[fName](getActorPtr(self), r[1], r[2], r[3], r[4])
		else
			C[fName](getActorPtr(self), r, g, b, a)
		end
		return self
	end
end
FFIUtils.setColorGenerator = setColorGenerator
Actor.SetDiffuse = setColorGenerator "ActorSetDiffuse"
Actor.diffuse = Actor.SetDiffuse
Actor.SetDiffuseUpperLeft = setColorGenerator "ActorSetDiffuseUpperLeft"
Actor.diffuseupperleft = Actor.SetDiffuseUpperLeft
Actor.SetDiffuseUpperRight = setColorGenerator "ActorSetDiffuseUpperRight"
Actor.diffuseupperright = Actor.SetDiffuseUpperRight
Actor.SetDiffuseLowerLeft = setColorGenerator "ActorSetDiffuseLowerLeft"
Actor.diffuselowerleft = Actor.SetDiffuseLowerLeft
Actor.SetDiffuseLowerRight = setColorGenerator "ActorSetDiffuseLowerRight"
Actor.diffuselowerright = Actor.SetDiffuseLowerRight
Actor.SetDiffuseLeftEdge = setColorGenerator "ActorSetDiffuseLeftEdge"
Actor.diffuseleftedge = Actor.SetDiffuseLeftEdge
Actor.SetDiffuseRightEdge = setColorGenerator "ActorSetDiffuseRightEdge"
Actor.diffuserightedge = Actor.SetDiffuseRightEdge
Actor.SetDiffuseTopEdge = setColorGenerator "ActorSetDiffuseTopEdge"
Actor.diffusetopedge = Actor.SetDiffuseTopEdge
Actor.SetDiffuseBottomEdge = setColorGenerator "ActorSetDiffuseBottomEdge"
Actor.diffusebottomedge = Actor.SetDiffuseBottomEdge
Actor.SetDiffuseAlpha = generator("ActorSetDiffuseAlpha", 1)
Actor.diffusealpha = Actor.SetDiffuseAlpha
Actor.SetDiffuseColor = setColorGenerator "ActorSetDiffuseColor"
Actor.diffusecolor = Actor.SetDiffuseAlpha
Actor.SetGlow = setColorGenerator "ActorSetGlow"
Actor.glow = Actor.SetGlow
--]]
Actor.SetAux = generator("ActorSetAux", 1)
Actor.GetAux = generator("ActorGetAux", 0, true)
Actor.SetRotationX = generator("ActorSetRotationX", 1)
Actor.SetRotationY = generator("ActorSetRotationY", 1)
Actor.SetRotationZ = generator("ActorSetRotationZ", 1)
Actor.AddRotationX = generator("ActorAddRotationX", 1)
Actor.AddRotationY = generator("ActorAddRotationY", 1)
Actor.AddRotationZ = generator("ActorAddRotationZ", 1)
Actor.aux = Actor.SetAux
Actor.getaux = Actor.GetAux
Actor.rotationx = Actor.SetRotationX
Actor.rotationy = Actor.SetRotationY
Actor.rotationz = Actor.SetRotationZ
Actor.addrotationx = Actor.AddRotationX
Actor.addrotationy = Actor.AddRotationY
Actor.addrotationz = Actor.AddRotationZ
do
	--[[
	The most efficient multiple return idea i could find was allocating a buffer once
	and filling it in the function.
	Owning/Allocating it in the lua side makes accessing it super simple
	--]]
	local buf = ffi.new("float[3]")
	Actor.GetRotation = function(self)
		C.ActorGetRotation(getActorPtr(self), buf)
		return {buf[0], buf[1], buf[2]}
	end
end
Actor.getrotation = Actor.GetRotation
Actor.SetBaseRotationX = generator("ActorSetBaseRotationX", 1)
Actor.SetBaseRotationY = generator("ActorSetBaseRotationY", 1)
Actor.SetBaseRotationZ = generator("ActorSetBaseRotationZ", 1)
Actor.SetSkewX = generator("ActorSetSkewX", 1)
Actor.SetSkewY = generator("ActorSetSkewY", 1)
Actor.Heading = generator("ActorHeading", 1)
Actor.Pitch = generator("ActorPitch", 1)
Actor.Roll = generator("ActorRoll", 1)
Actor.baerotationx = Actor.SetBaseRotationX
Actor.baserotationy = Actor.SetBaseRotationY
Actor.baserotationz = Actor.SetBaseRotationZ
Actor.skewy = Actor.SetSkewY
Actor.skewx = Actor.SetSkewX
Actor.heading = Actor.Heading
Actor.pitch = Actor.Pitch
Actor.roll = Actor.Roll
Actor.SetShadowLength = generator("ActorSetShadowLength", 1)
Actor.shadowlength = Actor.SetShadowLength
Actor.SetShadowLengthX = generator("ActorSetShadowLengthX", 1)
Actor.shadowlengthx = Actor.SetShadowLengthX
Actor.SetShadowLengthY = generator("ActorSetShadowLengthY", 1)
Actor.shadowlengthy = Actor.SetShadowLengthY
Actor.halign = generator("Actorhalign", 1)
Actor.valign = generator("Actorvalign", 1)
Actor.SetVertAlign = generator("ActorSetVertAlign", 1)
Actor.VertAlign = Actor.SetVertAlign
Actor.SetHorizAlign = generator("ActorSetHorizAlign", 1)
Actor.HorizAlign = Actor.SetHorizAlign
Actor.diffuseblink = generator("Actordiffuseblink", 0)
Actor.diffuseshift = generator("Actordiffuseshift", 0)
Actor.diffuseramp = generator("Actordiffuseramp", 0)
Actor.glowblink = generator("Actorglowblink", 0)
Actor.glowshift = generator("Actorglowshift", 0)
Actor.glowramp = generator("Actorglowramp", 0)
Actor.rainbow = generator("Actorrainbow", 0)
Actor.wag = generator("Actorwag", 0)
Actor.bounce = generator("Actorbounce", 0)
Actor.bob = generator("Actorbob", 0)
Actor.pulse = generator("Actorpulse", 0)
Actor.spin = generator("Actorspin", 0)
Actor.vibrate = generator("Actorvibrate", 0)
Actor.StopEffect = generator("ActorStopEffect", 0)
Actor.stopeffect = Actor.StopEffect
Actor.IsOver = generator("ActorIsOver", 2, true)
Actor.Draw = generator("ActorDraw", 1)
Actor.LoadXY = generator("ActorLoadXY", 0)
Actor.SaveXY = generator("ActorSaveXY", 2)
Actor.visible = function(self, b)
	-- We need to cast to boolean manually
	C.ActorSetVisible(getActorPtr(self), not (not b))
	return self
end
Actor.IsVisible = generator("ActorIsVisible", 0, true)
Actor.SetVisible = Actor.visible
Actor.SetDrawOrder = generator("ActorSetDrawOrder", 1)
Actor.draworder = Actor.SetDrawOrder
Actor.QueueCommand = generator("ActorQueueCommand", 1)
Actor.queuecommand = Actor.QueueCommand
Actor.QueueMessage = generator("ActorQueueMessage", 1)
Actor.queuemessage = Actor.QueueMessage
Actor.GetX = generator("ActorGetX", 0, true)
Actor.GetY = generator("ActorGetY", 0, true)
Actor.GetZ = generator("ActorGetZ", 0, true)
Actor.GetDestX = generator("ActorGetDestX", 0, true)
Actor.GetDestY = generator("ActorGetDestY", 0, true)
Actor.GetDestZ = generator("ActorGetDestZ", 0, true)
Actor.GetWidth = generator("ActorGetWidth", 0, true)
Actor.GetHeight = generator("ActorGetHeight", 0, true)
Actor.GetZoomedWidth = generator("ActorGetZoomedWidth", 0, true)
Actor.GetZoomedHeight = generator("ActorGetZoomedHeight", 0, true)
Actor.GetZoom = generator("ActorGetZoom", 0)
Actor.GetZoomX = generator("ActorGetZoomX", 0, true)
Actor.GetZoomY = generator("ActorGetZoomY", 0, true)
Actor.GetZoomZ = generator("ActorGetZoomZ", 0, true)
Actor.GetBaseZoomX = generator("ActorGetBaseZoomX", 0, true)
Actor.GetBaseZoomY = generator("ActorGetBaseZoomY", 0, true)
Actor.GetBaseZoomZ = generator("ActorGetBaseZoomZ", 0, true)
Actor.GetBaseRotationX = generator("ActorGetBaseRotationX", 0, true)
Actor.GetBaseRotationY = generator("ActorGetBaseRotationY", 0, true)
Actor.GetBaseRotationZ = generator("ActorGetBaseRotationZ", 0, true)
Actor.GetSecsIntoEffect = generator("ActorGetSecsIntoEffect", 0, true)
Actor.GetEffectDelta = generator("ActorGetEffectDelta", 0, true)
Actor.GetVisible = generator("ActorGetVisible", 0, true)
Actor.GetHAlign = generator("ActorGetHAlign", 0, true)
Actor.GetVAlign = generator("ActorGetVAlign", 0, true)
Actor.GetName = function(self)
	-- If something returns a char* we need to manually turn it
	-- into an interned lua string
	return ffi.string(C.ActorGetName(getActorPtr(self)))
end
generator("ActorGetName", 0, true)
Actor.SetFakeParent = function(self, fakeP)
	C.ActorSetFakeParent(getActorPtr(self), getActorPtr(fakeP))
	return self
end
ffi.cdef [[
	void SpriteLoad(void* a, const char* x);
	void SpriteLoadBanner(void* a, const char*x);
	void SpriteLoadBackground(void* a, const char* x);
	void SpriteLoadFromCached(void* a, const char* x, const char* y);
	void SpriteSetCustomTextureRect(void* a, float x, float y, float z, float h);
	void SpriteSetCustomImageRect(void* a, float x, float y, float z, float h);
	void SpriteSetCustomPosCoords(void* a, float* x);
	void SpriteStopUsingCustomPosCoords(void* a);
	void SpriteSetTexCoordVelocity(void* a, float x, float y);
	bool Spriteget_use_effect_clock_for_texcoords(void* a);
	void Spriteset_use_effect_clock_for_texcoords(void* a, bool x);
	void SpriteScaleToClipped(void* a, float x, float y);
	void SpriteCropTo(void* a, float x, float y);
	void SpriteStretchTex(void* a, float x, float y);
	void SpriteAddImageCoords(void* a, float x, float y);
	void SpriteSetState(void* a, int x);
	int SpriteGetState(void* a);
	float SpriteGetAnimationLengthSeconds(void* a);
	void SpriteSetSecondsIntoAnimation(void* a, float x);
	int SpriteGetNumStates(void* a);
	bool SpriteGetDecodeMovie(void* a);
	void SpriteSetDecodeMovie(void* a, bool x);
	//todo
	/*
		void SpriteSetStateProperties(void* a, Sprite::State* x, int n);
	void SpriteSetTexture(void* a, RageTexture* x);
	RageTexture* SpriteGetTexture(void* a);
	void SpriteSetEffectMode(void* a, EffectMode x);
	void SpriteSetAllStateDelays(void* a, float x);
	*/
]]
local generator = FFIUtils.generator
Sprite.Load = generator("SpriteLoad", 1)
Sprite.LoadBanner = generator("SpriteLoadBanner", 1)
Sprite.LoadBackground = generator("SpriteLoadBackground", 1)
Sprite.LoadFromCached = generator("SpriteLoadFromCached", 2)
Sprite.SetCustomTextureRect = generator("SpriteSetCustomTextureRect", 4)
Sprite.SetCustomImageRect = generator("SpriteSetCustomImageRect", 4)
Sprite.SetCustomPosCoords = generator("SpriteSetCustomPosCoords", 1)
Sprite.StopUsingCustomPosCoords = generator("SpriteStopUsingCustomPosCoords", 0)
Sprite.SetTexCoordVelocity = generator("SpriteSetTexCoordVelocity", 2)
Sprite.get_use_effect_clock_for_texcoords = generator("Spriteget_use_effect_clock_for_texcoords", 0, true)
Sprite.set_use_effect_clock_for_texcoords = generator("Spriteset_use_effect_clock_for_texcoords", 1)
Sprite.ScaleToClipped = generator("SpriteScaleToClipped", 2)
Sprite.CropTo = generator("SpriteCropTo", 2)
Sprite.StretchTex = generator("SpriteStretchTex", 2)
Sprite.AddImageCoords = generator("SpriteAddImageCoords", 2)
Sprite.SetState = generator("SpriteSetState", 1)
Sprite.GetState = generator("SpriteGetState", 0, true)
Sprite.GetAnimationLengthSeconds = generator("SpriteGetAnimationLengthSeconds", 0, true)
Sprite.SetSecondsIntoAnimation = generator("SpriteSetSecondsIntoAnimation", 1)
Sprite.GetNumStates = generator("SpriteGetNumStates", 0, true)
Sprite.GetDecodeMovie = generator("SpriteGetDecodeMovie", 0, true)
Sprite.SetDecodeMovie = function(self, b)
	-- We need to cast to boolean manually
	C.SpriteSetDecodeMovie(getActorPtr(self), not (not b))
	return self
end
