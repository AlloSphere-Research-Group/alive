print("running on", hostname)

local ffi = require "ffi"
local bit = require "bit"
local clang = require "clang"
local osc = require "osc"
local tube = require "tube"

ffi.cdef [[
size_t audiotube_writespace();
size_t audiotube_write(const char * src, size_t sz);

typedef struct tubeheader {
	size_t size;
	double t;
} tubeheader;

tube_t * atube_get() { return &atube; }
]]
local C = ffi.C

local atube = C.atube_get()


-- messages should actually contain:
	-- timestamp (double)
	-- size		(uint32)
	-- type		(uint32)
	-- data...	(char[?])


function onFrame()
	--print("onFrame")
	
	-- want something like
	--audio.send("foo")
	--audio.send("foo", ugenptr)
	--audio.send(ugenptr, paramidx, 0.5)
	-- i.e. strings, ints, doubles, pointers
	-- etc.
	
	local s = string.format("%f", os.time())
	--assert(tube.write(atube, s, #s), "failed to send")
	
	--tube.send(atube, os.time(), math.random())
end