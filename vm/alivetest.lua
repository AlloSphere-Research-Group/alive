-- force reload:
package.loaded.alive = nil

local alive = require "ffi.alive"
local gl = require "ffi.gl"

local start = os.time()

function alive:onKey(e, k)
	if e == "down" then
		if k == 27 then
			self:fullscreen(not self:fullscreen())
		end
	end
end

function draw()
	gl.ClearColor(0, 0, math.random(), 1)
	gl.Clear()
	
	gl.Color(1, 0, 0)
	gl.PushMatrix()
	gl.Scale(0.5)
	gl.Rotate(os.time() - start, 0, 0, -1)
	gl.Begin(gl.QUADS)
		gl.Vertex(0.3, 1, 0)
		gl.Vertex(-0.1, 1, 0)
		gl.Vertex(-1, -1, 0)
		gl.Vertex(1, -1, 0)
		
	gl.End()
	gl.PopMatrix()

end

function alive:onFrame(w, h)
	local h2 = h/2
	gl.Enable(gl.SCISSOR_TEST)
	
	gl.Viewport(0, 0, w, h2)
	gl.Scissor(0, 0, w, h2)
	draw()
	
	gl.Viewport(0, h2, w, h2)
	gl.Scissor(0, h2, w, h2)
	draw()
end

print("ok")