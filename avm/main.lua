local ffi = require "ffi"
local avm = require "avm"
local gl = require "gl"
local glutils = require "gl.utils"

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
world.nav.pos = world.dimhalf

audio.clear()
audio.start()

local t = 0.1
local nav_move = vec3(t, t, -t)
local t = math.pi * 0.01
local nav_turn = vec3(t, t, t)
local keydown = {
	[44]  = function() world.nav.move.x =  nav_move.x end,
	[46]  = function() world.nav.move.x = -nav_move.x end,
	[39]  = function() world.nav.move.y =  nav_move.y end,
	[47]  = function() world.nav.move.y = -nav_move.y end,
	[270] = function() world.nav.move.z = -nav_move.z end,
	[272] = function() world.nav.move.z =  nav_move.z end,
	
	[120] = function() world.nav.turn.x = -nav_turn.x end,
	[119] = function() world.nav.turn.x =  nav_turn.x end,
	[271] = function() world.nav.turn.y =  nav_turn.y end,
	[269] = function() world.nav.turn.y = -nav_turn.y end,
	[97]  = function() world.nav.turn.z = -nav_turn.z end,
	[100] = function() world.nav.turn.z =  nav_turn.z end,
	
	[96] = function()
		world.nav.pos = world.dimhalf
		world.nav.quat:identity()
	end,
	
	[string.byte("n")] = function() 
		--sugar:noise(0.000001)
	end,
}

local keyup = {
	[44]  = function() world.nav.move.x = 0 end,
	[46]  = function() world.nav.move.x = 0 end,
	[39]  = function() world.nav.move.y = 0 end,
	[47]  = function() world.nav.move.y = 0 end,
	[270] = function() world.nav.move.z = 0 end,
	[272] = function() world.nav.move.z = 0 end,
	
	[119] = function() world.nav.turn.x = 0 end,
	[120] = function() world.nav.turn.x = 0 end,
	[271] = function() world.nav.turn.y = 0 end,
	[269] = function() world.nav.turn.y = 0 end,
	[97]  = function() world.nav.turn.z = 0 end,
	[100] = function() world.nav.turn.z = 0 end,
}

function win:key(e, k)	
	if e == "down" then
		if keydown[k] then
			keydown[k]()
		elseif k == 27 then
			win.fullscreen = not win.fullscreen
		else
			print("unhandled key down", e, k)
		end
	else
		if keyup[k] then
			keyup[k]()
		else
			print("unhandled key up", e, k)
		end
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

local points = {}
for i = 1, 100 do
	points[i] = vec3(srandom(), srandom(), srandom()):add(world.dimhalf)
end

function win:draw()
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	
	gl.Viewport(0, 0, self.width, self.height)
	
	-- update navigation:
	world.nav:step()
	
	world.active_origin = world.nav.pos:clone():map(floor) - world.dimhalf
		
	audio.pos(world.nav.pos)
	audio.quat(world.nav.quat)
	
	
	gl.MatrixMode(gl.PROJECTION)
	gl.LoadMatrix(glutils.perspective(90, self.width/self.height, 0.1, 100))
	
	local q = world.nav.quat
	gl.MatrixMode(gl.MODELVIEW)
	gl.LoadMatrix(glutils.lookat(
		world.nav.pos,
		world.nav.pos - q:uz(),
		q:uy()
	))
	
	gl.Begin(gl.LINES)
	for i, p in ipairs(points) do
		gl.Vertex(p)
	end
	gl.End()
	
end
