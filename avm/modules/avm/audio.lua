local portaudio_h = require "portaudio_h"
local header = require "avm.header"

local ffi = require "ffi"
local lib = ffi.C

local function libfind(k)
	return lib[k]
end

local function resolve_symbol(self, k)
	local ok, sym = pcall(libfind, "Pa_"..k)
	if not ok then
		ok, sym = pcall(libfind, "Pa"..k)
		if not ok then
			ok, sym = pcall(libfind, "pa"..k)
			if not ok then
				error("could not resolve portaudio symbol " .. k)
			end
		end
	end
	self[k] = sym
	return sym
end

local pa = setmetatable({}, {
	__index = resolve_symbol,
}) 

local version_num = pa.GetVersion()
-- assert on version here, if necessary

print(ffi.string(pa.GetVersionText()))

local function check(err)
	if err ~= pa.NoError then
		error(pa.GetErrorText(err))
	end
end

check( pa.Initialize() )

-- search for a device by name:
function pa.find(name)
	local devices = pa.GetDeviceCount()
	for i = 0, devices-1 do
		local info = pa.GetDeviceInfo(i)
		if ffi.string(info.name) == name then
			return i
		end
	end
	error("could not find audio device "..name)
end

local function dump()
	local num_apis = pa.GetHostApiCount()
	print("num_apis", num_apis)

	local default_api = pa.GetDefaultHostApi()
	print("default_api", default_api)
	
	for i = 0, num_apis-1 do
		local info = pa.GetHostApiInfo(i)
		print("api", i)
		print(ffi.string(info.name))
		print("type", info.type)
		print("devices", info.deviceCount)
		print("default input", info.defaultInputDevice, pa.HostApiDeviceIndexToDeviceIndex(i, info.defaultInputDevice))
		print("default output", info.defaultOutputDevice, pa.HostApiDeviceIndexToDeviceIndex(i, info.defaultOutputDevice))
	end
	
	local devices = pa.GetDeviceCount()
	print("devices:", devices)
	local default_input = pa.GetDefaultInputDevice()
	print("default input", default_input)
	local default_output = pa.GetDefaultOutputDevice()
	print("default output", default_output)
	
	for i = 0, devices-1 do
		local info = pa.GetDeviceInfo(i)
		
		print("device", i, ffi.string(info.name))
		print("api index", info.hostApi)
		print("max inputs", info.maxInputChannels)
		print("max outputs", info.maxOutputChannels)
		print("defaultLowInputLatency", info.defaultLowInputLatency)
		print("defaultLowOutputLatency", info.defaultLowOutputLatency)
		print("defaultHighInputLatency", info.defaultHighInputLatency)
		print("defaultHighOutputLatency", info.defaultHighOutputLatency)
		print("defaultSampleRate", info.defaultSampleRate)
	end
	
end

--dump()


local Audio = {}

function Audio:__tostring()
	return string.format("Audio")
end


function Audio:__newindex(k, v)
		error("cannot assign to Audio: "..k)
end

function Audio:__index(k)
	return Audio[k]
end

setmetatable(Audio, {
	__index = function(self, k)
		Audio[k] = C["av_audio_" .. k]
		return Audio[k]
	end,
})

local stream = ffi.new("PaStream *")

function Audio:open(inchannels, outchannels, samplerate, blocksize)
	local errptr = ffi.new("PaError[1]")
	stream = lib.av_audio_open(inchannels, outchannels, samplerate, blocksize, errptr)
	check(errptr[0])
end

function Audio:start()
	local err = pa.StartStream(stream)
	check(err)
end

ffi.metatype("av_Audio", Audio)

return Audio
