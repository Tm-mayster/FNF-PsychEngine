-- LIGHTBREAKER: boss effects (camera bumps, flashes, light shakes) that follow the song's sections.
-- 185 BPM, 16 steps per bar. Kept subtle on purpose so the notes stay readable.

local BAR = 16
local sections = {          -- {start bar, name}
	{0, 'intro'}, {4, 'intro2'}, {8, 'a1'}, {24, 'a2'}, {40, 'b1'}, {48, 'b2'},
	{56, 'bridge'}, {64, 'c'}, {80, 'final'}, {88, 'outro'}
}
local current = 'intro'
local baseZoom = 0.78

local function sectionAt(step)
	local bar = math.floor(step / BAR)
	local name = 'intro'
	for _, s in ipairs(sections) do
		if bar >= s[1] then name = s[2] end
	end
	return name
end

local function flash(color, dur)
	if flashingLights then cameraFlash('camGame', color, dur, true) end
end

local function bump(game, hud)
	triggerEvent('Add Camera Zoom', tostring(game), tostring(hud))
end

function onCreatePost()
	baseZoom = getProperty('defaultCamZoom')
	setProperty('camZooming', true)
end

-- big moments when a new section starts
local function enterSection(name)
	if name == 'intro2' then
		bump(0.04, 0.02)
	elseif name == 'a1' or name == 'b1' then
		flash('C77DFF', 0.6)
		cameraShake('camGame', 0.006, 0.35)
		bump(0.06, 0.04)
	elseif name == 'a2' or name == 'b2' then
		flash('7DF9FF', 0.5)
		bump(0.05, 0.03)
	elseif name == 'bridge' then
		-- the calm part: the camera slowly leans in
		doTweenZoom('bridgeZoom', 'camGame', baseZoom + 0.12, 3, 'sineInOut')
		setProperty('defaultCamZoom', baseZoom + 0.12)
	elseif name == 'c' then
		-- the climax: pull back, white flash, short heavy shake
		setProperty('defaultCamZoom', baseZoom - 0.04)
		flash('FFFFFF', 0.8)
		cameraShake('camGame', 0.012, 0.5)
		cameraShake('camHUD', 0.003, 0.4)
		bump(0.08, 0.05)
	elseif name == 'final' then
		flash('FF6FD8', 0.6)
		cameraShake('camGame', 0.01, 0.45)
		bump(0.07, 0.04)
	elseif name == 'outro' then
		setProperty('defaultCamZoom', baseZoom)
		flash('FFFFFF', 1.2)
		cameraShake('camGame', 0.015, 0.8)
	end
end

function onStepHit()
	local name = sectionAt(curStep)
	if name ~= current then
		current = name
		enterSection(name)
	end
end

function onBeatHit()
	local name = current
	if name == 'a1' or name == 'a2' then
		-- light bump on every beat, a stronger one on the downbeat
		if curBeat % 4 == 0 then bump(0.025, 0.02) else bump(0.01, 0.006) end
	elseif name == 'b1' or name == 'b2' then
		bump(0.018, 0.012)
		if curBeat % 8 == 0 then cameraShake('camGame', 0.003, 0.15) end
	elseif name == 'c' or name == 'final' then
		bump(0.022, 0.014)
		-- purple lightning flicker every two bars, a tiny shake on the backbeat
		if curBeat % 8 == 0 then flash('8A3CFF', 0.25) end
		if curBeat % 2 == 1 then cameraShake('camGame', 0.002, 0.08) end
	elseif name == 'intro2' then
		if curBeat % 2 == 0 then bump(0.012, 0.006) end
	end
end

-- Nox's hits shake the screen a tiny bit in the loud parts
function opponentNoteHit(id, direction, noteType, isSustainNote)
	if not isSustainNote and (current == 'c' or current == 'final') and getRandomBool(18) then
		cameraShake('camGame', 0.0025, 0.06)
	end
end
