local header = require "avm.header"

local ffi = require "ffi"
local lib = ffi.C

local Audio = {}

function Audio:__tostring()
	return string.format("Audio")
end

function Audio:__newindex(k, v)
	error("cannot assign to Audio: "..k)
end

setmetatable(Audio, {
	__index = function(self, k)
		local sym = lib["av_audio_" .. k]
		Audio[k] = sym
		return sym
	end,
})

function Audio.pos(x, y, z)
	local msg = Audio.message()
	if msg ~= nil then
		msg.cmd = lib.AV_AUDIO_POS
		msg.x = x
		msg.y = y
		msg.z = z
		Audio.send()
	end
end

function Audio.quat(x, y, z, w)
	local msg = Audio.message()
	if msg ~= nil then
		msg.cmd = lib.AV_AUDIO_QUAT
		msg.x = world.nav.quat.x
		msg.y = world.nav.quat.y
		msg.z = world.nav.quat.z
		msg.w = world.nav.quat.w
		Audio.send()
	end	
end 

ffi.metatype("av_Audio", Audio)

return Audio.get()
