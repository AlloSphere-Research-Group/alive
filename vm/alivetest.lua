
print(string.rep("=", 80))

local ffi = require "ffi"
local C = ffi.C

ffi.cdef [[
	typedef int (*idle_callback)(int status);
	typedef void (*buffer_callback)(char * buffer, int size);
	
	void idle(idle_callback cb);
	
	void openfile(const char * path, buffer_callback cb);
	void openfd(int fd, buffer_callback cb);
	
	void al_sleep(double);
]]

C.openfd(0, function(buffer, size)
	print("received:", size)
	print(ffi.string(buffer, size))
end)

C.openfile("test.lua", function(buffer, size) 
	--print("read:", size)
	print(ffi.string(buffer, size))
end)

C.idle(function(status)
	-- return true to kill the idle function
	if math.random() < 0.001 then
		print("ticky")
	end
	return false
end)

print("ok")