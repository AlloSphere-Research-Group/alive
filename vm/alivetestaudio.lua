local ffi = require "ffi"
local C = ffi.C

ffi.cdef [[
	typedef void (*audio_callback)(double sampletime);
	
	float * audio_outbuffer(int chan);
	const float * audio_inbuffer(int chan);
	float * audio_busbuffer(int chan);
	float audio_samplerate();
	int audio_buffersize();
	int audio_channelsin();
	int audio_channelsout();	
	int audio_channelsbus();
	double audio_time();
	void audio_zeroout();
	double audio_cpu();
	void audio_set_callback(audio_callback cb);
	
	typedef struct audiomsg {
		double t;
		char data[24];
	} audiomsg;
	
	struct audiomsg * audioq_peek(void);
	struct audiomsg * audioq_next(void);
]]

function phasor(freq)
	local pincr = freq/C.audio_samplerate()
	local phase = 0
	return function()
		phase = (phase + pincr) % 1
		return phase
	end
end

function lag(amt)
	local y = 0
	return function(x)
		y = y + amt * (x-y)
		return y
	end
end

local ps = {}
for i = 1, 50 do
	ps[i] = phasor(1100 * math.random())
end

local cpu = 0.05
local flag = 0
local flaglag = lag(0.01)

C.audio_set_callback(function(sampletime)	
	local frames = C.audio_buffersize()
	local outs = C.audio_channelsout()
	local outputs = {}
	for c = 0, outs-1 do
		outputs[c] = C.audio_outbuffer(c)
	end
	
	local nexttime = sampletime + frames
	
	local m = C.audioq_peek()
	while m ~= nil and m.t < nexttime do
		-- TODO: use message...
		flag = 1
		
		-- get next message:
		m = C.audioq_next()
	end
	
	local out0 = C.audio_outbuffer(0)
	for i=0, frames-1 do
		local s = 0
		for j = 1, #ps do
			s = s + ps[j]() 
		end
		s = s * flag / #ps
		for c=0, outs-1 do
			outputs[c][i] = s -- * math.sin(t * math.pi * 4 * (c+1))
		end
		
	end
	flag = flag * 0.9
	
	
	local cpu1 = C.audio_cpu()
	if cpu1 > cpu then
		cpu = cpu1
		print("audio peak cpu", cpu)
	end
	
	-- TODO: tune this
	collectgarbage()
end)