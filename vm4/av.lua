local header = require "header"
local ffi = require "ffi"
local C = ffi.C

local m = {}

m.app = C.app_get()

return m