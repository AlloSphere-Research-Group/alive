--[[
	A basic startup script
--]]

print(string.rep("=", 80))

local ffi = require "ffi"
local Window = require "ffi.Window"
local gl = require "ffi.gl"
local C = ffi.C

require "ffi.aliveheader"

local m = {}

C.openfd(0, function(buffer, size)
	print("received:", size)
	print(ffi.string(buffer, size))
	return true
end)


local win = C.alive_window()
local wincb

function win:draw() 
	C.alive_tick()
	collectgarbage()
	if (wincb) then wincb(self, win:dim()) end
	collectgarbage()
end

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

