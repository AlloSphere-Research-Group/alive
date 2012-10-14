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

--local version_num = pa.GetVersion()
-- assert on version here, if necessary

local function check(err)
	if err ~= pa.NoError then
		error(ffi.string(pa.GetErrorText(err)))
	end
end

check( pa.Initialize() )

-- search for a device by name(s):
function pa.find(a)
	local devices = pa.GetDeviceCount()
	for i = 0, devices-1 do
		local info = pa.GetDeviceInfo(i)
		if ffi.string(info.name) == a then
			return i
		end
	end
end

local function dump()
	print(ffi.string(pa.GetVersionText()))
	
	--[[
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
	--]]
	
	local devices = pa.GetDeviceCount()
	local default_input = pa.GetDefaultInputDevice()
	local default_output = pa.GetDefaultOutputDevice()
	
	for i = 0, devices-1 do
		local info = pa.GetDeviceInfo(i)
		
		local msg = ""
		if i == default_input then
			msg = msg .. "<input>"
		end
		if i == default_output then
			msg = msg .. "<output>"
		end
		
		print(string.format("dev %d: %dx%d %s %s",
			i, info.maxInputChannels, info.maxOutputChannels, ffi.string(info.name), msg
		))
		--print("defaultLowInputLatency", info.defaultLowInputLatency)
		--print("defaultLowOutputLatency", info.defaultLowOutputLatency)
		--print("defaultHighInputLatency", info.defaultHighInputLatency)
		--print("defaultHighOutputLatency", info.defaultHighOutputLatency)
		--print("defaultSampleRate", info.defaultSampleRate)
		--print("api index", info.hostApi)
		
	end
	
end

dump()


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
		Audio[k] = lib["av_audio_" .. k]
		return Audio[k]
	end,
})

local stream = ffi.new("PaStream *")

function Audio:open(inchannels, outchannels, samplerate, blocksize, indevname, outdevname)
	local inchannels = inchannels or 2
	local outchannels = outchannels or 2
	
	local samplerate = samplerate or 44100
	local blocksize = blocksize or 256
	
	local indev = pa.GetDefaultInputDevice()
	if indevname then
		if type(indevname) == "string" then
			indev = pa.find(indevname) or indev
		else
			indev = indevname
		end
	end
	
	local outdev = pa.GetDefaultOutputDevice()
	if outdevname then
		if type(outdevname) == "string" then
			outdev = pa.find(outdevname) or outdev
		else
			outdev = outdevname
		end
	end
	
	local errptr = ffi.new("PaError[1]")
	stream = lib.av_audio_open(inchannels, outchannels, samplerate, blocksize, indev, outdev, errptr)
	check(errptr[0])
end

ffi.metatype("av_Audio", Audio)

return Audio
