local audio = require "avm.audio"

local p = 0

function audio:callback(time, inputs, outputs, frames)
	local out0 = outputs
	local out1 = outputs + frames
	
	-- process incoming messages
	
	-- play voices
	for i = 0, frames-1 do
		p = p + 440 * math.pi * 2/audio.samplerate
		out0[i] = math.sin(p)
		out1[i] = 0 --math.random()
	end
	
	-- TODO: tune this
	collectgarbage()
end
