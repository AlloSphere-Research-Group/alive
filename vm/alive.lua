print("running on", hostname)
print("argv", unpack(argv))

--[[

This app is launched by the proxy.js node, to which stdio is connected.
If it crashes, the proxy.js node can restart it.
Otherwise, it runs continuously, updating itself in response to file changes.

It needs to have a main file to run and a directory to watch.

For that, it needs filewatching capabilities.

--]]

local ffi = require "ffi"
local C = ffi.C

function onFrame()
	
	print(".")
	print(io.stdin:read(1))
end

