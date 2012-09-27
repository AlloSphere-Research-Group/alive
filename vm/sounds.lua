local tube = require "tube"

local ffi = require "ffi"
ffi.cdef [[
	typedef struct AudioIOData AudioIOData;

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
	
	size_t audiotube_readspace();
	size_t audiotube_read(char * dst, size_t sz);
	size_t audiotube_peek(char * dst, size_t sz);
	
	typedef struct tubeheader {
		size_t size;
		double t;
	} tubeheader;
	
	tube_t * atube_get() { return &atube; }
]]
local C = ffi.C
headersize = ffi.sizeof("tubeheader")

local atube = C.atube_get()

function onMsg(msg)

end

local h = ffi.new("tubeheader")

-- incoming message buffer:
local dst = ffi.new("char[64]")
	
function onAudioCB(io)
	--print("tock")
	local frames = C.audio_buffersize()
	local outs = C.audio_channelsout()
	local outputs = {}
	for c = 0, outs-1 do
		outputs[c] = C.audio_outbuffer(c)
	end
	local time = C.audio_time()
	--print(time)
	
	-- handle incoming messages on the tube:
	
	--[[	
	while tube.read(atube, dst, 64) > 0 do
		print("recv", ffi.string(dst))
	end
	--]]
	--print(tube.recv(atube))
		
	for i=0, frames-1 do
		for c=0, outs-1 do
			--outputs[c][i] = math.random() * math.sin(time * math.pi * 4 * (c+1))
		end
	end
end