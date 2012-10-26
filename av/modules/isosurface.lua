local sin, cos, tan = math.sin, math.cos, math.tan
local asin, acos, atan, atan2 = math.asin, math.acos, math.atan, math.atan2
local sqrt, pow, abs = math.sqrt, math.pow, math.abs
local min, max = math.min, math.max
local floor = math.floor
local pi = math.pi
local format = string.format

local header = require "avm.header"

local ffi = require "ffi"
local lib = ffi.C

local iso = {}
iso.__index = iso

setmetatable(iso, {
	__call = function(_, dim)
		-- TODO: ffi.gc this
		return lib.av_isosurface_create(dim)
	end,
	__index = function(self, k)
		iso[k] = lib["av_isosurface_" .. k]
		return iso[k]
	end,
})	

ffi.metatype("av_Isosurface", iso)

return iso