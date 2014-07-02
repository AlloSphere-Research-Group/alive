local ffi = require "ffi"
local lib = ffi.load("world")

--local vec2 = require "vec2"
local vec3 = require "vec3"
local vec4 = require "vec4"
local quat = require "quat"

ffi.cdef(require "world_h")

return lib