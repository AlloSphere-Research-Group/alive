local header = require "avm.header"

local ffi = require "ffi"
local lib = ffi.C

local function libfind(k)
	return lib[k]
end

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
		local sym = lib["av_audio_" .. k]
		Audio[k] = sym
		return sym
	end,
})

ffi.metatype("av_Audio", Audio)

return Audio
