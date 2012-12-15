local header = require "av.header"

local ffi = require "ffi"
local lib = ffi.C

local m = {}
m.__index = m

setmetatable(m, {
	__index = function(s, k)
		local name = "av_image_"..k
		m[k] = lib[name]
		return m[k]
	end,
	__call = function(_, path)
		return ffi.gc(m.load(path), lib.av_image_free)
	end,
})

ffi.metatype("av_Image", m)

return m
