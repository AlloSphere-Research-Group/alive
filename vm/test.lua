print("hello")

local ffi = require("ffi")
ffi.cdef [[
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

function sleep(s)
	ffi.C.poll(nil, 0, s*1000)
end

while true do
	--print("tick")
	print("tick")
	sleep(0.001)
end