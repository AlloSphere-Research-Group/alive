--[[
	A basic startup script
--]]

print(string.rep("=", 80))

local ffi = require "ffi"
local Window = require "ffi.Window"
local gl = require "ffi.gl"
local C = ffi.C

ffi.cdef [[
	typedef struct al_Window al_Window;

	typedef int (*idle_callback)(int status);
	typedef int (*buffer_callback)(char * buffer, int size);
	typedef int (*filewatcher_callback)(const char * filename);
	
	void idle(idle_callback cb);
	void openfile(const char * path, buffer_callback cb);
	void openfd(int fd, buffer_callback cb);
	void watchfile(const char * filename, filewatcher_callback cb);
	
	al_Window * alive_window();
	void alive_tick();
	
	void al_sleep(double);
]]

C.openfd(0, function(buffer, size)
	print("received:", size)
	print(ffi.string(buffer, size))
	return true
end)

--[[
C.openfile("alive.h", function(buffer, size) 
	--print("read:", size)
	--print(ffi.string(buffer, size))
	return true
end)
--]]

C.idle(function(status)
	return true
end)

--[[
C.watchfile("alive.cpp", function(filename)
	print("modified", ffi.string(filename))
	return true
end)
--]]

local win = C.alive_window()
local wincb

function win:draw() 
	C.alive_tick()
	if (wincb) then wincb(self, win:dim()) end
end

local m = {}

setmetatable(m, {
	__newindex = function(self, name, value)
		if name == "onFrame" then
			wincb = value
		elseif name == "onKey" then
			win.key = value
		end
	end,
})

return m