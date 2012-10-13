local ffi = require "ffi"
local C = ffi.C

local gl = require "gl"

local h = require "avm.header"
print(h)

print("hello there you all")

local win = C.window_get()


function win:onframe()
	
	gl.ClearColor(math.random() * 0.2, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	
	gl.Viewport(0, 0, self.width, self.height)
	
end




