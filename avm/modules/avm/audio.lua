local portaudio_h = require "portaudio_h"
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
			error("could not resolve portaudio symbol " .. k)
		end
	end
	self[k] = sym
	return sym
end

local pa = setmetatable({}, {
	__index = resolve_symbol,
}) 

local version_num = pa.GetVersion()
-- assert on version here, if necessary

print(ffi.string(pa.GetVersionText()))

return pa
