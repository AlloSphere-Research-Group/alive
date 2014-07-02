#!/usr/local/bin/luajit

local ffi = require "ffi"
local C = ffi.C

local function exec(...)
	local c = string.format(...)
	print(c)
	local f = io.popen(c)
	print(f:read("*a"))
end

if ffi.os == "OSX" then
	exec("g++ -O3 -fPIC -DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__MACOSX_CORE__ -DOSC_HOST_LITTLE_ENDIAN -Iinclude *.cpp allosystem/*.cpp allosystem/*.mm allosystem/oscpack/osc/*.cpp -framework Cocoa -framework CoreFoundation -framework IOKit -framework OpenGL -framework GLUT -framework CoreAudio -lfreeimage -lapr-1 -laprutil-1 -lportaudio -pagezero_size 10000 -image_base 100000000 -lluajit-5.1 -lev -o ../master/main")
else
	print("untested OS")
end

