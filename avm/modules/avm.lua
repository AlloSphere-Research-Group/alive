local ffi = require 'ffi'
local C = ffi.C

local header = require 'avm.header'
local window = require 'avm.window'
local audio = require 'avm.audio'



local m = {
	window = C.av_window_create(),
	audio = C.av_audio_get(),
}

return m