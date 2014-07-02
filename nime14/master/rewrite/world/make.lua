local ffi = require "ffi"
local C = ffi.C

local function exec(...)
	local c = string.format(...)
	print(c)
	local f = io.popen(c)
	print(f:read("*a"))
end

if ffi.os == "OSX" then
	exec("g++ -arch i386 -arch x86_64 -O3 -fPIC -DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__MACOSX_CORE__ *.cpp -framework Cocoa -framework CoreFoundation -framework IOKit -framework OpenGL -framework GLUT -framework CoreAudio -shared -o ../libworld.dylib")
else
	print("untested OS")
end

local h = io.open("world.h"):read("*a")

local f = io.open("../world_h.lua", "w")
f:write("return [[" .. h .. "]]")
f:close()

return true