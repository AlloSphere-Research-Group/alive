local ffi = require "ffi"

local avm = require "avm"
local gl = require "gl"

-- currently just one window:
local win = avm.window
local audio = avm.audio

audio:start()

function win:resize(w, h)
	print("resize", w, h)
end

function win:mouse(e, b, x, y)
	--print(e, b, x, y)
end

function win:key(e, k)	
	if e == "down" then
		if k == 27 then
			print("currently", win.fullscreen)
			print("to", not win.fullscreen)
			win.fullscreen = not win.fullscreen
		end
	else
		print("key", e, k)
		
		-- e.g. trigger a sound... 
		
	end
end

function win:draw()
	gl.ClearColor(math.random() * 0.2, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	
	gl.Viewport(0, 0, self.width, self.height)
	
	
	
	
	
end
