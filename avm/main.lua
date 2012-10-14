local ffi = require "ffi"
local avm = require "avm"
local gl = require "gl"
local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat
local nav = require "nav"

local random = math.random
local srandom = function() return random()*2-1 end
local rad, deg = math.rad, math.deg
local min, max = math.min, math.max
local sin, cos = math.sin, math.cos
local ceil, floor = math.ceil, math.floor
local pi = math.pi

-- currently just one window:
local win = avm.window
local audio = avm.audio


world = world or {
	dim = vec3(32, 32, 32),
	nav = nav(),
	active_origin = vec3(0, 0, 0),	
	infinite = true,
	ambient_color = vec3(
		0.3 + 0.1*srandom(), 
		0.3 + 0.1*srandom(), 
		0.3 + 0.1*srandom()
	),
}
world.dimhalf = world.dim/2
world.nav.pos = world.nav.pos or world.dimhalf

audio.clear()
audio.start()

function win:key(e, k)	
	if e == "down" then
		if k == 27 then
			win.fullscreen = not win.fullscreen
		end
	else
		print("key", e, k)
		
		-- e.g. trigger a sound... 
		
	end
end

function win:mouse(e, b, x, y)
	--print(e, b, x, y)
end

function win:resize(w, h)
	print("resize", w, h)
end

function win:create()
	-- create shaders, buffers, textures etc. here
	gl.ClearColor(world.ambient_color.x, world.ambient_color.y, world.ambient_color.z)
	
	
end

function win:draw()
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	
	gl.Viewport(0, 0, self.width, self.height)
	
	-- update navigation:
	world.nav:step()
	
	world.active_origin = world.nav.pos:clone():map(floor) - world.dimhalf
		
	audio.pos(world.nav.pos)
	audio.quat(world.nav.quat)
	
end
