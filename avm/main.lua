local ffi = require "ffi"
local avm = require "avm"
local gl = require "gl"
local glutils = require "gl.utils"
local Shader = require "gl.Shader"

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

local vs = [[
#version 110

//attribute vec3 position;
//attribute vec3 normal;
//attribute vec4 color;
attribute vec4 rotate;
attribute vec3 translate;
attribute vec3 scale;

uniform float far;

varying vec4 C;
varying vec3 N;
varying float F;

//	q must be a normalized quaternion
vec3 quat_rotate(vec4 q, vec3 v) {
	// qv = vec4(v, 0) // 'pure quaternion' derived from vector
	// return ((q * qv) * q^-1).xyz
	// reduced to 24 multiplies and 17 additions:
	vec4 p = vec4(
		q.w*v.x + q.y*v.z - q.z*v.y,	// x
		q.w*v.y + q.z*v.x - q.x*v.z,	// y
		q.w*v.z + q.x*v.y - q.y*v.x,	// z
		-q.x*v.x - q.y*v.y - q.z*v.z	// w
	);
	return vec3(
		p.x*q.w - p.w*q.x + p.z*q.y - p.y*q.z,	// x
		p.y*q.w - p.w*q.y + p.x*q.z - p.z*q.x,	// y
		p.z*q.w - p.w*q.z + p.y*q.x - p.x*q.y	// z
	);
}

void main() {
	vec3 position = gl_Vertex.xyz;
	vec3 P = translate + quat_rotate(rotate, position * scale);

	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(P, 1.);
	
	// fog effect
	float dist = gl_Position.z / far;
	F = 1.-pow(dist, 4.);
	
	N = gl_Normal;	// normal
	C = gl_Color;	// color
}
]]

local fs = [[
#version 110

uniform vec3 ambient;

varying vec4 C;
varying vec3 N;
varying float F;

void main() {
	
	vec3 L = vec3(1, 1, -1);
	float l = max(0., dot(N, L));
	
	vec3 color = ambient + C.rgb*l;
	
	gl_FragColor = vec4(color, C.a*F) + vec4(1);
}
]]

local phong = Shader(vs, fs)

function win:create()
	-- create shaders, buffers, textures etc. here
	gl.ClearColor(world.ambient_color.x, world.ambient_color.y, world.ambient_color.z)
	
	-- create shader:
	phong:create()
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
	
	phong:bind()
	phong:uniform("far", 64)
	
	phong:attribute("translate", 0, 0, 0)
	phong:attribute("rotate", 0, 0, 0, 1)
	phong:attribute("scale", 1, 1, 1)
		
	gl.Begin(gl.LINES)
	gl.Color(1,1,1)
	for i, p in ipairs(points) do
		gl.Vertex(p)
	end
	gl.End()
	
	phong:unbind()
	
end
