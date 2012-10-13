local ffi = require 'ffi'
local C = ffi.C

local header = require 'avm.header'
local window = require 'avm.window'





local m = {
	window = C.av_window_create(),
}

return m