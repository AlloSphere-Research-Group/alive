local audio = require "avm.audio"
local ffi = require "ffi"
local C = ffi.C

local p = 0

local view = {
	pos = {},
	quat = {},
}

local voices = {}

function audio:callback(time, inputs, outputs, frames)
	local out0 = outputs
	local out1 = outputs + frames
	
	-- process incoming messages
	local m = self.peek(time)
	while m ~= nil do
		
		local cmd = m.cmd
		if cmd == C.AV_AUDIO_VOICE_NEW then
			voices[m.id] = {
				ugen = fly(((m.id % 10) + srandom() * 0.2) * 110),
				pos = Vec3f(),
			}
			
		elseif cmd == C.AV_AUDIO_VOICE_FREE then
			voices[m.id] = nil
			
		elseif cmd == C.AV_AUDIO_VOICE_POS then
			voices[m.id].pos.x = m.x
			voices[m.id].pos.y = m.y
			voices[m.id].pos.z = m.z
			
		elseif cmd == C.AV_AUDIO_POS then
			view.pos.x = m.x
			view.pos.y = m.y
			view.pos.z = m.z
			
		elseif cmd == C.AV_AUDIO_QUAT then
			view.quat.x = m.x
			view.quat.y = m.y
			view.quat.z = m.z
			view.quat.w = m.w
		elseif cmd == C.AV_AUDIO_CLEAR then
			for k, v in pairs(voices) do
				voices[k] = nil
			end
		end

		m = self.next(time)
	end
	
	-- play voices
	for i = 0, frames-1 do
		--p = p + 440 * math.pi * 2/audio.samplerate
		--out0[i] = math.sin(p)
		--out1[i] = 0 --math.random()
	end
	
	-- TODO: tune this
	collectgarbage()
end
