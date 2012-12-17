

local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

ffi.cdef [[
	typedef struct al_Thread al_Thread;
	al_Thread * al_thread_new(const char * scriptpath, double period);
	void al_thread_free(al_Thread * self);
	int al_thread_start(al_Thread * self);
]]

-- the module:
local Thread = {
	start = lib.al_thread_start,
}
Thread.__index = Thread

setmetatable(Thread, {
	__call = function(class, path, period)
		local s = lib.al_thread_new(path, period)
		ffi.gc(s, lib.al_thread_free)
		return s
	end,
})

ffi.metatype("al_Thread", Thread)

return Thread