local header = require "av.header"

local ffi = require "ffi"
local lib = ffi.C

local Audio = {}
Audio.__index = Audio

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

function Audio.clear()
	local msg = Audio.message()
	if msg ~= nil then
		msg.cmd = lib.AV_AUDIO_CLEAR
		Audio.send()
	end
end

function Audio.pos(v, id)
	if id then
		local msg = Audio.message()
		if msg ~= nil then
			msg.cmd = lib.AV_AUDIO_VOICE_POS
			msg.id = id
			msg.x = v.x
			msg.y = v.y
			msg.z = v.z
			Audio.send()
		end
	else
		local msg = Audio.message()
		if msg ~= nil then
			msg.cmd = lib.AV_AUDIO_POS
			msg.x = v.x
			msg.y = v.y
			msg.z = v.z
			Audio.send()
		end
	end
end

function Audio.quat(q)
	local msg = Audio.message()
	if msg ~= nil then
		msg.cmd = lib.AV_AUDIO_QUAT
		msg.x = q.x
		msg.y = q.y
		msg.z = q.z
		msg.w = q.w
		Audio.send()
	end	
end 

function Audio.voice(id)
	local msg = Audio.message()
	if msg ~= nil then
		msg.cmd = lib.AV_AUDIO_VOICE_NEW
		msg.id = id
			Audio.send()
	else
		error("audio message queue overflow")
	end
end

ffi.metatype("av_Audio", Audio)

return Audio.get()
